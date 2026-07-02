# frozen_string_literal: true

module RedmineIssueMerge
  class Hooks < Redmine::Hook::ViewListener
    # "In anderes Ticket ueberfuehren"-Link (Partial) - wird per JS in ALLE
    # .contextual-Leisten geklont (jeweils vor span.drdn).
    render_on :view_issues_show_details_bottom, partial: 'issue_merges/merge_link'

    # CSS-Box (aus den Einstellungen) + JS: Merge-Notiz entstylen und
    # Aktionslink in die .contextual-Leiste(n) einbinden.
    def view_layouts_base_html_head(_context = {})
      s = Setting.plugin_redmine_issue_merge

      css = +'.redmine-merge-box{'
      css << "border:#{css_safe(s['box_border'])};"
      css << "padding:#{css_safe(s['box_padding'])};"
      css << "background:#{css_safe(s['box_background'])};"
      css << "color:#{css_safe(s['box_color'])};"
      css << 'border-radius:4px;margin:4px 0;}'
      css << '.redmine-merge-box p:first-of-type{font-weight:bold;margin-top:0;}'

      "<style>#{css}</style>#{merge_script}".html_safe
    end

    private

    # Fix 3: CSS-Werte aus den (admin-gesetzten) Einstellungen werden global in
    # einen <style>-Block geschrieben. Ohne Filter waere ein Wert wie
    # "#000}</style><script>..." ein Stored-XSS-Vektor. Daher harte Whitelist:
    # nur Zeichen, die in Farb-/Border-/Padding-Werten vorkommen. Damit sind
    # <>{}"';:/ und Backslash ausgeschlossen (kein Ausbruch aus style/value,
    # kein url(...)-Trick). Zusaetzlich Laengenbegrenzung.
    def css_safe(value)
      value.to_s.gsub(/[^a-zA-Z0-9 #%.,()\-]/, '')[0, 100].to_s
    end

    # Literales Heredoc: kein Ruby-Escaping, JS wird 1:1 ausgegeben.
    # MARK muss mit RedmineIssueMerge::MARKER uebereinstimmen ('%%MERGE%%').
    def merge_script
      <<~'JS'
        <script>
        (function(){
          var MARK = '%%MERGE%%';

          // 1) Merge-Notiz erkennen, Marker entfernen, Box-Klasse setzen.
          function decorate(root){
            (root || document).querySelectorAll('.wiki').forEach(function(el){
              if (el.dataset.mergeDone) return;
              var t = (el.textContent || '').replace(/^\s+/, '');
              if (t.indexOf(MARK) === 0){
                el.dataset.mergeDone = '1';
                el.classList.add('redmine-merge-box');
                el.innerHTML = el.innerHTML
                  .replace(MARK, '')
                  .replace(/<p>\s*<br[^>]*>/i, '<p>')
                  .replace(/<p>\s*<\/p>\s*/i, '');
              }
            });
          }

          // 2) Aktionslink in ALLE .contextual-Leisten einbinden,
          //    jeweils vor span.drdn (bzw. ans Ende, falls keine da).
          function relocate(){
            var wrap = document.querySelector('.redmine-merge-action');
            if (!wrap) return;
            var srcA = wrap.querySelector('a');
            if (!srcA) { wrap.remove(); return; }

            document.querySelectorAll('#content .contextual').forEach(function(ctx){
              if (ctx.querySelector('a.redmine-merge-clone')) return; // schon drin
              var a = srcA.cloneNode(true);
              a.classList.add('redmine-merge-clone');
              var drdn = ctx.querySelector('span.drdn');
              if (drdn) { ctx.insertBefore(a, drdn); }
              else      { ctx.appendChild(a); }
            });

            wrap.parentNode && wrap.remove();
          }

          function run(){ decorate(); relocate(); }

          if (document.readyState !== 'loading') { run(); }
          else { document.addEventListener('DOMContentLoaded', run); }
          document.addEventListener('ajax:complete', function(){ decorate(); });
        })();
        </script>
      JS
    end
  end
end
