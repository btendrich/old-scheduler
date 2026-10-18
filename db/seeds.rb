# Local desk login only. Production venues and users are created by hand.
return unless Rails.env.development?

venue = Venue.find_or_create_by!(name: "Alice Tully Hall") { |record| record.time_zone = "America/New_York" }

User.find_or_create_by!(email_address: "desk@example.com") do |user|
  user.venue = venue
  user.password = "password"
end
