module Messenger
  class RestaurantsFlexMessageValue
    attr_reader :restaurant_data_subset_id, :selected_restaurants, :next_page, :meal_type
    def initialize(restaurant_data_subset_id, current_page)
      restaurant_data_subset = RestaurantDataSubset.find(restaurant_data_subset_id)
      from, to = restaurant_data_subset.create_mongo_index(current_page)

      @restaurant_data_subset_id = restaurant_data_subset_id
      @next_page = restaurant_data_subset.next_page(current_page)
      @meal_type = restaurant_data_subset.meal_type
      @selected_restaurants = restaurant_data_subset.selected_restaurants[from..to]
    end

    def line_post_param
      contents = selected_restaurants.map do |restaurant|
        struct_restaurant(restaurant)
      end
      contents.push(see_more_contents) if next_page

      {
        "type": "flex",
        "altText": "レストランのご紹介",
        "contents": {
          "type": "carousel",
          "contents": contents
        }
      }
    end

    private

    def struct_restaurant(restaurant)
      {
        "type": "bubble",
        "hero": {
          "type": "image",
          "url": restaurant[:thumbnail_image_urls][0],
          "size": "full",
          "aspectRatio": "20:15",
          "aspectMode": "cover"
        },
        "body": {
          "type": "box",
          "layout": "vertical",
          "contents": struct_body_blocks(restaurant),
        },
        "footer": {
          "type": "box",
          "layout": "vertical",
          "spacing": "sm",
          "contents": struct_actions(restaurant[:redirect_url]),
          "flex": 0
        }
      }
    end

    def struct_body_blocks(restaurant)
      contents = []

      contents << {
        "type": "text",
        "text": restaurant[:name],
        "weight": "bold",
        "size": "lg"
      }

      contents << {
        "type": "text",
        "text": "⭐️評価#{restaurant[:rating]}/5",
        "size": "sm",
        "margin": "md"
      }

      budget = restaurant[meal_type+"_budget"]
      contents << struct_budget_block(budget)

      contents << struct_genre_block(restaurant[:area_genre])

      return contents
    end

    def struct_budget_block(budget)
      lower_budget, upper_budget = budget
      budget_text = lower_budget != 0 ? "#{lower_budget}円~#{upper_budget}円" : "~#{upper_budget}円"
      {
        "type": "box",
        "layout": "vertical",
        "margin": "lg",
        "spacing": "sm",
        "contents": [
          {
            "type": "box",
            "layout": "baseline",
            "spacing": "md",
            "contents": [
              {
                "type": "text",
                "text": "予算",
                "color": "#aaaaaa",
                "size": "xs",
                "flex": 5
              }
            ]
          },
          {
            "type": "box",
            "layout": "baseline",
            "spacing": "md",
            "contents": [
              {
                "type": "text",
                "text": budget_text,
                "wrap": true,
                "size": "sm",
                "flex": 5
              }
            ]
          }
        ]
      }
    end

    def struct_genre_block(genre)
      {
        "type": "box",
        "layout": "vertical",
        "margin": "lg",
        "spacing": "sm",
        "contents": [
          {
            "type": "box",
            "layout": "baseline",
            "spacing": "md",
            "contents": [
              {
                "type": "text",
                "text": "ジャンル",
                "color": "#aaaaaa",
                "size": "xs",
                "flex": 5
              }
            ]
          },
          {
            "type": "box",
            "layout": "baseline",
            "spacing": "md",
            "contents": [
              {
                "type": "text",
                "text": genre,
                "wrap": true,
                "size": "sm",
                "flex": 5
              }
            ]
          }
        ]
      }
    end

    def struct_actions(redirect_url)
      [
        {
          "type": "separator",
          "margin": "md"
        },
        {
          "type": "button",
          "style": "link",
          "height": "sm",
          "action": {
            "type": "uri",
            "label": "👉レストランを予約する👈",
            "uri": redirect_url
          }
        }
      ]
    end

    def see_more_contents
      {
        "type": "bubble",
        "body": {
          "type": "box",
          "layout": "vertical",
          "spacing": "sm",
          "contents": [
            {
              "type": "button",
              "flex": 1,
              "gravity": "center",
              "action": {
                "type": "postback",
                "label": "もっと見る",
                "data": "restaurant_data_subset_id=#{restaurant_data_subset_id}&page=#{next_page}"
                # "data": "mongo_custom_restaurants_id=#{mongo_custom_restaurants_id}&page=#{next_page}"
              }
            }
          ]
        }
      }
    end

  end
end