Pod::Spec.new do |s|

  s.name          = "DrawerKit"
  s.version       = "0.0.1"
  s.summary       = "An implementation of an interactive and animated view, similar to what you see in Apple Maps"

  s.description   = <<-DESC
DrawerKit allows you to modally present a view controller from another, in such a way that the
presented view controller slides up as a "drawer", much like what happens when you tap on a location
in the map when using the Apple Maps app. The library is highly configurable, with a few more options
coming soon.
                   DESC

  s.homepage      = "https://github.com/Babylonpartners/DrawerKit/blob/master/README.md"
  s.license       = { :type => "MIT", :file => "LICENSE" }
  s.author        = { "Wagner Truppel" => "wagner.truppel@babylonhealth.com" }
  s.platform      = :ios, "10.3"
  s.source        = { :git => "github.com/Babylonpartners/DrawerKit.git", :tag => "#{s.version}" }
  s.source_files  = "Classes/**/*.{swift}"
  s.exclude_files = "Classes/Exclude"

end