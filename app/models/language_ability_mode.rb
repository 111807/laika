class LanguageAbilityMode < ActiveRecord::Base
  named_scope :all, :order => 'name ASC'
end
