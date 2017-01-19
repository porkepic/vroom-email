Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  post "/email", to: "receive#email"
  post "/bounce", to: "receive#bounce"
  post "/delivery", to: "receive#delivery"
  post "/open", to: "receive#open"

end
