# CP2112

[![Gem Version](https://badge.fury.io/rb/cp2112.svg)](https://badge.fury.io/rb/cp2112)

Ruby wrapper for Silicon Laboratories CP2112 USB(HID) i2c/SMBus bridge library

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cp2112'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cp2112

## Usage

```ruby
require 'cp2112'

dev = CP2112[0, 0x10C4, 0xEA90] # [index, vendor id, product id], [0x10C4, 0xEA90] are default parameters
raise unless dev.getPartNumber[0] == 0x0C # must always be 0xC0

gpio_new = [
  0x03, # GPIO.0-1: OUT, GPIO.2-7:IN
  0x00, # open-drain
  0x00, # GPIO
  0x00, # clkDiv
]
dev.setGpioConfig(*gpio_new)
raise unless (dev.getGpioConfig == gpio_new)
50.times{|i| # toggle GPIO.0-1
  bits = dev.readLatch[0]
  dev.writeLatch(bits ^ 0x03, 0x03)
  sleep(0.02)
}

# Read via I2C
#dev.i2c_read(addr, size) # addr is shifted by 1 bit (0bAAAA_AAAx, A=0/1, x=ignored)

# Write via I2C
#dev.i2c_write(addr, data) # byte array data is expected; data = [byte, ...]

# TODO: your i2c_read, i2c_write operation

# Other instance methods of dev is defined based on AN496
# https://www.silabs.com/documents/public/application-notes/an496-hid-usb-to-smbus-api-specification.pdf#page=2
# https://www.silabs.com/documents/public/application-notes/an496-hid-usb-to-smbus-api-specification.pdf#page=21

dev.close
```

## Development

After checking out the repo, run `rake compile` to install dependencies. Then, run `rake spec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fenrir-naru/ruby-cp2112.
