# Each pack's public entry point is `app/public/<pack>/api.rb` defining `<Pack>::API`.
Rails.autoloaders.each { |loader| loader.inflector.inflect("api" => "API") }
