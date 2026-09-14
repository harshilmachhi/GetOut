require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'ExpoPlaceSearch'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = package['license']
  s.author         = 'GetOut'
  s.homepage       = 'https://github.com'
  s.platforms      = { :ios => '16.4' }
  s.source         = { :path => '.' }
  s.dependency 'ExpoModulesCore'
  s.frameworks = 'MapKit', 'Contacts'
  s.static_framework = true
  s.source_files = '**/*.{h,m,swift}'
end
