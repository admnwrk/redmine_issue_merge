get  'issues/:issue_id/merge', to: 'issue_merges#new',    as: 'new_issue_merge'
post 'issues/:issue_id/merge', to: 'issue_merges#create', as: 'issue_merge'
