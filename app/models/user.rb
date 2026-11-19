class User < ApplicationRecord
  has_secure_password

  enum :skill_level, { beginner: 1, Intermediate: 2, Expert: 3 }, validate: true
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :display_name, presence: true
  validates :date_of_birth, presence: true
  validates :skill_level, presence: true
end
