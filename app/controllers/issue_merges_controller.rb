# frozen_string_literal: true

class IssueMergesController < ApplicationController
  before_action :find_issue, :authorize

  # Formular: Zielticket + Kopfzeile waehlen
  def new
    @default_header = default_header(@issue)
  end

  # Durchfuehrung
  def create
    target = find_target(params[:target_id])
    if target.nil?
      flash[:error] = l(:error_merge_target_not_found)
      return redirect_to(new_issue_merge_path(issue_id: @issue.id))
    end
    if target.id == @issue.id
      flash[:error] = l(:error_merge_same_issue)
      return redirect_to(new_issue_merge_path(issue_id: @issue.id))
    end
    # Fix 1: Schreibrecht wird auf BEIDEN Seiten geprueft. Quellticket wird
    # geschlossen (edit_issues Quelle), Zielticket bekommt Notiz + Anhaenge
    # (edit_issues Ziel). Sichtbarkeit des Ziels allein reicht NICHT.
    unless User.current.allowed_to?(:edit_issues, @issue.project)
      flash[:error] = l(:error_merge_no_edit_permission)
      return redirect_to(new_issue_merge_path(issue_id: @issue.id))
    end
    unless User.current.allowed_to?(:edit_issues, target.project)
      flash[:error] = l(:error_merge_no_edit_permission_target)
      return redirect_to(new_issue_merge_path(issue_id: @issue.id))
    end
    # Vorab-Pruefung: gibt es ueberhaupt einen geschlossenen Zielstatus?
    # (Eigene, sprechende Meldung statt der generischen Fehlerbehandlung.)
    if closed_status.nil?
      flash[:error] = l(:error_merge_no_closed_status)
      return redirect_to(new_issue_merge_path(issue_id: @issue.id))
    end

    header = params[:header_text].presence || default_header(@issue)

    Issue.transaction do
      perform_merge(@issue, target, header)
    end

    flash[:notice] = l(:notice_merge_success, id: target.id)
    redirect_to issue_path(target)
  # Methodenebenen-Rescue: faengt ALLES ab (auch einen Ziel-Lookup, der wider
  # Erwarten wirft) -> nie mehr ein roher 500er.
  rescue ActiveRecord::RecordNotFound
    flash[:error] = l(:error_merge_target_not_found)
    redirect_to(new_issue_merge_path(issue_id: @issue.id))
  rescue StandardError => e
    # Fix 5: Nur eine generische Meldung an den Benutzer, keine internen
    # Details (SQL/Pfade). Die echte Exception nur ins Server-Log.
    Rails.logger.error("[redmine_issue_merge] #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
    flash[:error] = l(:error_merge_failed)
    redirect_to(new_issue_merge_path(issue_id: @issue.id))
  end

  private

  def find_issue
    @issue = Issue.find(params[:issue_id])
    # Fix 4: Ticket-Ebenen-Sichtbarkeit erzwingen (die Projekt-Autorisierung
    # allein deckt z. B. "nur eigene Tickets" nicht ab).
    return render_403 unless @issue.visible?

    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_target(raw)
    id = raw.to_s.gsub(/[^0-9]/, '')
    return nil if id.blank?

    Issue.visible.find_by(id: id.to_i)
  end

  def default_header(source)
    tpl = Setting.plugin_redmine_issue_merge['header_template'].presence ||
          'Eintrag/Merge aus Duplikat #%{source}'
    tpl.gsub('%{source}', source.id.to_s)
  end

  # Kernlogik. Laeuft komplett innerhalb einer Transaktion (create).
  def perform_merge(source, target, header)
    moved = source.attachments.to_a
    notes = build_merge_notes(source, header, moved)

    # 1) Alles als EIN Journal-Eintrag ins Zielticket.
    journal = Journal.new(journalized: target, user: User.current, notes: notes)
    journal.notify = false # keine Mailflut durch den Merge
    journal.save!

    # 2) Anhaenge umhaengen: nur der Fremdschluessel wandert,
    #    die Dateien auf der Platte bleiben unberuehrt.
    moved.each do |a|
      a.update_columns(container_id: target.id, container_type: 'Issue')
    end

    # 3) Beziehung Duplikat -> Zielticket (reversibel, ueberall sichtbar).
    begin
      IssueRelation.create(
        issue_from:    source,
        issue_to:      target,
        relation_type: IssueRelation::TYPE_DUPLICATES
      )
    rescue StandardError
      # z. B. bereits vorhandene/zirkulaere Relation -> ignorieren
    end

    # 4) Duplikat schliessen (NICHT loeschen) + Rueckverweis ins Quell-Journal.
    status = closed_status
    raise l(:error_merge_no_closed_status) if status.nil?

    source.reload
    source.init_journal(User.current, l(:notice_merged_into, id: target.id))
    source.status = status
    source.save!
  end

  def closed_status
    cfg = Setting.plugin_redmine_issue_merge['closed_status_id']
    status = IssueStatus.find_by(id: cfg) if cfg.present?
    status || IssueStatus.where(is_closed: true).order(:position).first
  end

  def build_merge_notes(source, header, moved_attachments)
    parts = []
    parts << RedmineIssueMerge::MARKER
    parts << ''
    parts << header
    parts << ''
    parts << "**#{l(:label_merge_source)} ##{source.id}: #{source.subject}**"

    if source.description.present?
      parts << ''
      parts << source.description.to_s
    end

    if Setting.plugin_redmine_issue_merge['include_source_journals'].to_s == '1'
      # Fix 2: KEINE privaten Notizen uebernehmen - der Merge-Eintrag ist
      # oeffentlich; private Notizen wuerden sonst fuer alle sichtbar, die das
      # Zielticket sehen koennen. private_notes ist in Redmine NOT NULL
      # (Default false), daher genuegt der explizite false-Filter.
      source.journals
             .where.not(notes: [nil, ''])
             .where(private_notes: false)
             .reorder(:created_on).each do |j|
        parts << ''
        parts << '----'
        parts << ''
        parts << "*#{j.user.try(:name)}, #{j.created_on.strftime('%d.%m.%Y %H:%M')}*"
        parts << ''
        parts << j.notes.to_s
      end
    end

    if moved_attachments.any?
      parts << ''
      parts << '----'
      parts << ''
      parts << "**#{l(:label_merge_moved_attachments)}:** " +
               moved_attachments.map(&:filename).join(', ')
    end

    parts.join("\n")
  end
end
