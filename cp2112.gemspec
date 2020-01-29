
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "cp2112/version"

Gem::Specification.new do |spec|
  spec.name          = "cp2112"
  spec.version       = CP2112::VERSION
  spec.authors       = ["fenrir(M.Naruoka)"]
  spec.email         = ["fenrir.naru@gmail.com"]

  spec.summary       = %q{Ruby wrapper for Silicon Laboratories CP2112 USB(HID) i2c/SMBus bridge library}
  spec.description   = %q{cp2112 is a Ruby wrapper for shared library of CP2112, a USB(HID) i2c/SMBus bridge device, which is distributed by Silicon Laboratories.}
  spec.homepage      = "https://github.com/fenrir-naru/ruby-cp2112"
  spec.license       = "BSD-3-Clause"

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
