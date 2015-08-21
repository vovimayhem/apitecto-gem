# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do

  # Minimal Factory:
  factory :post do

    sequence :body do |n|
      "Valid post #{n}"
    end

    factory :invalid_post do
      sequence :body do |n|
        "Invalid post #{n}"
      end
    end
  end

end

###################
