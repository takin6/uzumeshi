module Api
  module RestaurantDataSets
    class CreateUsecase
      attr_reader :params, :chat_unit
      def initialize(params, chat_unit)
        @params = params
        @chat_unit = chat_unit
      end

      def execute
        user = chat_unit.user

        restaurant_data_set = RestaurantDataSet.create!(
          selected_restaurant_ids: params[:selected_restaurant_ids],
          user_id: user.id
        )

        return restaurant_data_set.id
      end
    end
  end
end