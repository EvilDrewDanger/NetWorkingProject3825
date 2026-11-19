class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :display_name, null: false
      t.date :date_of_birth, null: false
      t.integer :skill_level, null: false, default: 1
      t.string :password_digest, null: false

      t.timestamps
    end

    add_index :users, "lower(username)", unique: true, name: "index_users_on_lower_username"
  end
end
