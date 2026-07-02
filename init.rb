# frozen_string_literal: true

require_relative 'lib/redmine_issue_merge'

Redmine::Plugin.register :redmine_issue_merge do
  name        'Redmine Issue Merge'
  author      'Chris'
  description 'Fuehrt ein Duplikat-Ticket in ein bestehendes Ticket ueber: alle Inhalte als EIN Journal-Eintrag (in konfigurierbarem CSS-Kasten), Anhaenge umgehaengt, Duplikat als Duplikat verlinkt und geschlossen. Keine Schema-/DB-Migration noetig.'
  version     '1.1.0'
  url         ''
  author_url  ''

  requires_redmine version_or_higher: '6.0.0'

  settings(
    default: {
      # %{source} wird durch die ID des Duplikats ersetzt.
      'header_template'         => 'Eintrag/Merge aus Duplikat #%{source}',
      'box_border'              => '1px solid #c9a227',
      'box_padding'             => '10px 12px',
      'box_background'          => '#fff8e1',
      'box_color'               => '#1a1a1a',
      'include_source_journals' => '1',
      'closed_status_id'        => ''
    },
    partial: 'settings/redmine_issue_merge_settings'
  )

  project_module :issue_tracking do
    permission :merge_issues, { issue_merges: %i[new create] }, require: :member
  end
end
