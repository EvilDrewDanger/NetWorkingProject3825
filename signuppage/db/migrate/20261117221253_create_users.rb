class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :display_name, null: false
      t.date :date_of_birth, null: false
      t.integer :skill_level, null: false, default: 1
      t.string :password_digest, null: false

      t.timestamps

      add_index :users, :username, unique: true
    end
  end
end
