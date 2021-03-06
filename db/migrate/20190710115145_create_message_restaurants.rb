class CreateMessageRestaurants < ActiveRecord::Migration[5.2]
  def change
    create_table :message_restaurants do |t|
      t.belongs_to :message, null: false, foreign_key: true

      t.string :mongo_custom_restaurants_id, null: false
      t.integer :page, null: false, default: 1
      t.timestamps
    end
  end
end
