require "cp2112/version"

require "fiddle/import"
require "fiddle/types"

module CP2112
  
  module WinAPI
    extend Fiddle::Importer
    dlload 'kernel32.dll'
    include Fiddle::Win32Types
    extern 'int SetDllDirectory(LPCSTR)'
    # @see https://ja.stackoverflow.com/questions/60784/windows-%E3%81%AE-ruby-%E3%81%AE-fiddle-%E3%81%A7-lib-dll-%E3%81%8C%E8%AA%AD%E3%81%BF%E8%BE%BC%E3%82%81%E3%81%AA%E3%81%84%E6%99%82-%E4%BD%95%E3%82%92%E3%83%81%E3%82%A7%E3%83%83%E3%82%AF%E3%81%99%E3%82%8C%E3%81%B0%E3%82%88%E3%81%84%E3%81%A7%E3%81%97%E3%82%87%E3%81%86%E3%81%8B
  end
  
  extend Fiddle::Importer
  
  @@dll_name ||= 'SLABHIDtoSMBus.dll'
  @@dll_dirs ||= proc{
    root = (RUBY_PLATFORM =~ /cygwin/) ? ['/cygdrive', 'c'] : ['C:']
    [
      ['.'] # current dir
    ] + $:.collect{|dir| # automatically downloaded library
      ['x86', 'x64'].collect{|arch|
        [dir, 'cp2112', 'silabs', 'Windows'] + [arch]
      }
    }.flatten(1) + ['x86', 'x64'].collect{|arch|
      # default install dirs
      root + ['SiliconLabs', 'MCU', 'CP2112_SDK', 'Library', 'Windows'] + [arch]
    }
  }.call
  @@dll_setup ||= proc{|dll|
    path = File::expand_path(File::dirname(dll))
    path = `cygpath -w #{path}`.chomp if (RUBY_PLATFORM =~ /cygwin/)
    WinAPI.SetDllDirectory(path)
  }
  
  raise "Cannot load HID dll!" unless proc{
    @@dll_dirs.any?{|dir|
      dll = File::join(*((dir || []) + [@@dll_name]))
      next false unless File::exist?(dll)
      begin
        @@dll_setup.call(dll)
        dlload(dll)
        true
      rescue
        false
      end
    }
  }.call
  
  include Fiddle::Win32Types
  
  typealias('HID_SMBUS_STATUS', 'int')
  typealias('HID_SMBUS_DEVICE', 'void*')
  typealias('HID_SMBUS_S0', 'BYTE')
  typealias('HID_SMBUS_S1', 'BYTE')
  
  def CP2112.get_ptr(type)
    array, type = [1, type.to_s]
    size = if type =~ /\[(\d*)\]$/ then
      type, array = [$`, $1.to_i]
      array = 0x200 if array <= 0
      CP2112::sizeof(type) * array
    else
      CP2112::sizeof(type)
    end
    content = Fiddle::malloc(size)
    ptr = Fiddle::Pointer[content]
    if (array > 1) && ("char" == type) then
      ptr.define_singleton_method(:to_value){self.to_str(size).unpack('Z*')[0]}
    else
      ctype = parse_ctype(type, type_alias)
      packer = Fiddle::Packer[ctype]
      packer.instance_eval{
=begin
Fix bug in original library; negative value means unsigned type
An unsigned value is treated with the same manner of a signed value in the original library. 
Therefore, modification of @template, which is used for unpack method, is performed.
Alternative way is
module Fiddle
  PackInfo::PACK_MAP[-TYPE_CHAR]  = "C"
  PackInfo::PACK_MAP[-TYPE_SHORT] = "S!"
  PackInfo::PACK_MAP[-TYPE_INT]   = "I!"
  PackInfo::PACK_MAP[-TYPE_LONG]  = "L!"
end
, which affects globally.
=end
        @template.sub!(/^./){$&.upcase} if ctype < 0
        @template.sub!(/$/, array.to_s) if array > 1
      }
      ptr.define_singleton_method(:to_value){
        values = packer.unpack([self.to_str(size)])
        (array == 1) ? values[0] : values
      }
    end
    return ptr
  end
  
  module Return_Code
    CONST_TABLE = {
      :STATUS => { # HID_SMBUS_STATUS Return Codes
        :HID_SMBUS_SUCCESS => 0x00,
        :HID_SMBUS_DEVICE_NOT_FOUND => 0x01,
        :HID_SMBUS_INVALID_HANDLE => 0x02,
        :HID_SMBUS_INVALID_DEVICE_OBJECT => 0x03,
        :HID_SMBUS_INVALID_PARAMETER => 0x04,
        :HID_SMBUS_INVALID_REQUEST_LENGTH => 0x05,
        
        :HID_SMBUS_READ_ERROR => 0x10,
        :HID_SMBUS_WRITE_ERROR => 0x11,
        :HID_SMBUS_READ_TIMED_OUT => 0x12,
        :HID_SMBUS_WRITE_TIMED_OUT => 0x13,
        :HID_SMBUS_DEVICE_IO_FAILED => 0x14,
        :HID_SMBUS_DEVICE_ACCESS_ERROR => 0x15,
        :HID_SMBUS_DEVICE_NOT_SUPPORTED => 0x16,
        
        :HID_SMBUS_UNKNOWN_ERROR => 0xFF,
      },
    
      :S0 => { # HID_SMBUS_TRANSFER_S0
        :HID_SMBUS_S0_IDLE => 0x00,
        :HID_SMBUS_S0_BUSY => 0x01,
        :HID_SMBUS_S0_COMPLETE => 0x02,
        :HID_SMBUS_S0_ERROR => 0x03,
      },
    
      :S1_BUSY => { # HID_SMBUS_TRANSFER_S1
        :HID_SMBUS_S1_BUSY_ADDRESS_ACKED => 0x00,
        :HID_SMBUS_S1_BUSY_ADDRESS_NACKED => 0x01,
        :HID_SMBUS_S1_BUSY_READING => 0x02,
        :HID_SMBUS_S1_BUSY_WRITING => 0x03,
      },
      
      :S1_ERROR => { # HID_SMBUS_TRANSFER_S1
        :HID_SMBUS_S1_ERROR_TIMEOUT_NACK => 0x00,
        :HID_SMBUS_S1_ERROR_TIMEOUT_BUS_NOT_FREE => 0x01,
        :HID_SMBUS_S1_ERROR_ARB_LOST => 0x02,
        :HID_SMBUS_S1_ERROR_READ_INCOMPLETE => 0x03,
        :HID_SMBUS_S1_ERROR_WRITE_INCOMPLETE => 0x04,
        :HID_SMBUS_S1_ERROR_SUCCESS_AFTER_RETRY => 0x05,
      },
    }
    
    CONST_TABLE.collect{|k, v| v.to_a}.flatten(1).each{|k, v| const_set(k, v)}
  end
  
  class <<self
    # define class methods such as CP2112::status
    Return_Code::CONST_TABLE.keys.each{|k| 
      define_method(k.to_s.downcase.to_sym, proc{|i| Return_Code::CONST_TABLE[k].find([nil]){|k2, v| v == i}[0]})
    }
  end

  module String_Definitions
    # Product String Types
    HID_SMBUS_GET_VID_STR = 0x01
    HID_SMBUS_GET_PID_STR = 0x02
    HID_SMBUS_GET_PATH_STR = 0x03
    HID_SMBUS_GET_SERIAL_STR = 0x04
    HID_SMBUS_GET_MANUFACTURER_STR = 0x05
    HID_SMBUS_GET_PRODUCT_STR = 0x06
    
    # String Lengths
    HID_SMBUS_DEVICE_STRLEN = 260
  end
  
  module SMBUS_Definitions
    # SMbus Configuration Limits
    HID_SMBUS_MIN_BIT_RATE = 1
    HID_SMBUS_MIN_TIMEOUT = 0
    HID_SMBUS_MAX_TIMEOUT = 1000
    HID_SMBUS_MAX_RETRIES = 1000
    HID_SMBUS_MIN_ADDRESS = 0x02
    HID_SMBUS_MAX_ADDRESS = 0xFE
    
    # Read/Write Limits
    HID_SMBUS_MIN_READ_REQUEST_SIZE = 1
    HID_SMBUS_MAX_READ_REQUEST_SIZE = 512
    HID_SMBUS_MIN_TARGET_ADDRESS_SIZE = 1
    HID_SMBUS_MAX_TARGET_ADDRESS_SIZE = 16
    HID_SMBUS_MAX_READ_RESPONSE_SIZE = 61
    HID_SMBUS_MIN_WRITE_REQUEST_SIZE = 1
    HID_SMBUS_MAX_WRITE_REQUEST_SIZE = 61
  end

  module GPIO_Definitions
    # GPIO Pin Direction Bit Value
    HID_SMBUS_DIRECTION_INPUT = 0
    HID_SMBUS_DIRECTION_OUTPUT = 1
    
    # GPIO Pin Mode Bit Value
    HID_SMBUS_MODE_OPEN_DRAIN = 0
    HID_SMBUS_MODE_PUSH_PULL = 1
    
    # GPIO Function Bitmask
    HID_SMBUS_MASK_FUNCTION_GPIO_7_CLK = 0x01
    HID_SMBUS_MASK_FUNCTION_GPIO_0_TXT = 0x02
    HID_SMBUS_MASK_FUNCTION_GPIO_1_RXT = 0x04
    
    # GPIO Function Bit Value
    HID_SMBUS_GPIO_FUNCTION = 0
    HID_SMBUS_SPECIAL_FUNCTION = 1
    
    # GPIO Pin Bitmask
    HID_SMBUS_MASK_GPIO_0 = 0x01
    HID_SMBUS_MASK_GPIO_1 = 0x02
    HID_SMBUS_MASK_GPIO_2 = 0x04
    HID_SMBUS_MASK_GPIO_3 = 0x08
    HID_SMBUS_MASK_GPIO_4 = 0x10
    HID_SMBUS_MASK_GPIO_5 = 0x20
    HID_SMBUS_MASK_GPIO_6 = 0x40
    HID_SMBUS_MASK_GPIO_7 = 0x80
  end
  
  module Part_Number_Definitions
    # Part Numbers
    HID_SMBUS_PART_CP2112 = 0x0C
  end
  
  module User_Customization_Definitions
    # User-Customizable Field Lock Bitmasks
    HID_SMBUS_LOCK_VID = 0x01
    HID_SMBUS_LOCK_PID = 0x02
    HID_SMBUS_LOCK_POWER = 0x04
    HID_SMBUS_LOCK_POWER_MODE = 0x08
    HID_SMBUS_LOCK_RELEASE_VERSION = 0x10
    HID_SMBUS_LOCK_MFG_STR = 0x20
    HID_SMBUS_LOCK_PRODUCT_STR = 0x40
    HID_SMBUS_LOCK_SERIAL_STR = 0x80
    
    # Field Lock Bit Values
    HID_SMBUS_LOCK_UNLOCKED = 1
    HID_SMBUS_LOCK_LOCKED = 0
    
    # Power Max Value (500 mA)
    HID_SMBUS_BUS_POWER_MAX = 0xFA
    
    # Power Modes
    HID_SMBUS_BUS_POWER = 0x00
    HID_SMBUS_SELF_POWER_VREG_DIS = 0x01
    HID_SMBUS_SELF_POWER_VREG_EN = 0x02
    
    # USB Config Bitmasks
    HID_SMBUS_SET_VID = 0x01
    HID_SMBUS_SET_PID = 0x02
    HID_SMBUS_SET_POWER = 0x04
    HID_SMBUS_SET_POWER_MODE = 0x08
    HID_SMBUS_SET_RELEASE_VERSION = 0x10
    
    # USB Config Bit Values
    HID_SMBUS_SET_IGNORE = 0
    HID_SMBUS_SET_PROGRAM = 1

    # String Lengths
    HID_SMBUS_CP2112_MFG_STRLEN = 30
    HID_SMBUS_CP2112_PRODUCT_STRLEN = 30
    HID_SMBUS_CP2112_SERIAL_STRLEN = 30
  end
  
  class Device; end
  
  {
    # API Functions
    'HID_SMBUS_STATUS HidSmbus_GetNumDevices(DWORD*, WORD, WORD)' => [0],
    'HID_SMBUS_STATUS HidSmbus_GetString(DWORD, WORD, WORD, char[], DWORD)' => [3],
    'HID_SMBUS_STATUS HidSmbus_GetOpenedString(HID_SMBUS_DEVICE, char[], DWORD)' => [1],
    'HID_SMBUS_STATUS HidSmbus_GetIndexedString(DWORD, WORD, WORD, DWORD, char[])' => [4],
    'HID_SMBUS_STATUS HidSmbus_GetOpenedIndexedString(HID_SMBUS_DEVICE, DWORD, char[])' => [2],
    'HID_SMBUS_STATUS HidSmbus_GetAttributes(DWORD, WORD, WORD, WORD*, WORD*, WORD*)' => [3, 4, 5],
    'HID_SMBUS_STATUS HidSmbus_GetOpenedAttributes(HID_SMBUS_DEVICE, WORD*, WORD*, WORD*)' => [1, 2, 3],
    'HID_SMBUS_STATUS HidSmbus_Open(HID_SMBUS_DEVICE*, DWORD, WORD, WORD)' => [0],
    'HID_SMBUS_STATUS HidSmbus_Close(HID_SMBUS_DEVICE)' => [],
    'HID_SMBUS_STATUS HidSmbus_IsOpened(HID_SMBUS_DEVICE, BOOL*)' => [1],
    'HID_SMBUS_STATUS HidSmbus_ReadRequest(HID_SMBUS_DEVICE, BYTE, WORD)' => [],
    'HID_SMBUS_STATUS HidSmbus_AddressReadRequest(HID_SMBUS_DEVICE, BYTE, WORD, BYTE, BYTE*)' => [],
    'HID_SMBUS_STATUS HidSmbus_ForceReadResponse(HID_SMBUS_DEVICE, WORD)' => [],
    "HID_SMBUS_STATUS HidSmbus_GetReadResponse(HID_SMBUS_DEVICE, HID_SMBUS_S0*, BYTE[#{SMBUS_Definitions::HID_SMBUS_MAX_READ_RESPONSE_SIZE}], BYTE, BYTE*)" => [1, 2, [3, SMBUS_Definitions::HID_SMBUS_MAX_READ_RESPONSE_SIZE], 4],
    'HID_SMBUS_STATUS HidSmbus_WriteRequest(HID_SMBUS_DEVICE, BYTE, BYTE*, BYTE)' => [],
    'HID_SMBUS_STATUS HidSmbus_TransferStatusRequest(HID_SMBUS_DEVICE)' => [],
    'HID_SMBUS_STATUS HidSmbus_GetTransferStatusResponse(HID_SMBUS_DEVICE, HID_SMBUS_S0*, HID_SMBUS_S1*, WORD*, WORD*)' => [1, 2, 3, 4],
    'HID_SMBUS_STATUS HidSmbus_CancelTransfer(HID_SMBUS_DEVICE)' => [],
    'HID_SMBUS_STATUS HidSmbus_CancelIo(HID_SMBUS_DEVICE)' => [],
    'HID_SMBUS_STATUS HidSmbus_SetTimeouts(HID_SMBUS_DEVICE, DWORD)' => [],
    'HID_SMBUS_STATUS HidSmbus_GetTimeouts(HID_SMBUS_DEVICE, DWORD*)' => [1],
    'HID_SMBUS_STATUS HidSmbus_SetSmbusConfig(HID_SMBUS_DEVICE, DWORD, BYTE, BOOL, WORD, WORD, BOOL, WORD)' => [],
    'HID_SMBUS_STATUS HidSmbus_GetSmbusConfig(HID_SMBUS_DEVICE, DWORD*, BYTE*, BOOL*, WORD*, WORD*, BOOL*, WORD*)' => (1..7).to_a,
    'HID_SMBUS_STATUS HidSmbus_Reset(HID_SMBUS_DEVICE)' => [],
    'HID_SMBUS_STATUS HidSmbus_SetGpioConfig(HID_SMBUS_DEVICE, BYTE, BYTE, BYTE, BYTE)' => [],
    'HID_SMBUS_STATUS HidSmbus_GetGpioConfig(HID_SMBUS_DEVICE, BYTE*, BYTE*, BYTE*, BYTE*)' => (1..4).to_a,
    'HID_SMBUS_STATUS HidSmbus_ReadLatch(HID_SMBUS_DEVICE, BYTE*)' => [1],
    'HID_SMBUS_STATUS HidSmbus_WriteLatch(HID_SMBUS_DEVICE, BYTE, BYTE)' => [],
    'HID_SMBUS_STATUS HidSmbus_GetPartNumber(HID_SMBUS_DEVICE, BYTE*, BYTE*)' => [1, 2],
    'HID_SMBUS_STATUS HidSmbus_GetLibraryVersion(BYTE*, BYTE*, BOOL*)' => (0..2).to_a,
    'HID_SMBUS_STATUS HidSmbus_GetHidLibraryVersion(BYTE*, BYTE*, BOOL*)' => (0..2).to_a,
    'HID_SMBUS_STATUS HidSmbus_GetHidGuid(void*)' => [], # TODO
    # User Customization API Functions
    'HID_SMBUS_STATUS HidSmbus_SetLock(HID_SMBUS_DEVICE, BYTE)' => [],
    'HID_SMBUS_STATUS HidSmbus_GetLock(HID_SMBUS_DEVICE, BYTE*)' => [1],
    'HID_SMBUS_STATUS HidSmbus_SetUsbConfig(HID_SMBUS_DEVICE, WORD, WORD, BYTE, BYTE, WORD, BYTE)' => [],
    'HID_SMBUS_STATUS HidSmbus_GetUsbConfig(HID_SMBUS_DEVICE, WORD*, WORD*, BYTE*, BYTE*, WORD*)' => (1..5).to_a,
    'HID_SMBUS_STATUS HidSmbus_SetManufacturingString(HID_SMBUS_DEVICE, char[], BYTE)' => [],
    'HID_SMBUS_STATUS HidSmbus_GetManufacturingString(HID_SMBUS_DEVICE, char[], BYTE*)' => [1, 2],
    'HID_SMBUS_STATUS HidSmbus_SetProductString(HID_SMBUS_DEVICE, char[], BYTE)' => [],
    'HID_SMBUS_STATUS HidSmbus_GetProductString(HID_SMBUS_DEVICE, char[], BYTE*)' => [1, 2],
    'HID_SMBUS_STATUS HidSmbus_SetSerialString(HID_SMBUS_DEVICE, char[], BYTE)' => [],
    'HID_SMBUS_STATUS HidSmbus_GetSerialString(HID_SMBUS_DEVICE, char[], BYTE*)' => [1, 2],
  }.each{|func, args_auto|
    extern(func) # enable original function
    next unless func =~ /HidSmbus_([^\(]+)\(([^)]+)\)$/
    fname, args = [$1, $2.split(/, */).collect{|type| type.sub(/\*$/, '').to_sym}]
    fname_orig = "HidSmbus_#{fname}".to_sym
    # alternative function having return value helper
    args_auto_buf = args_auto.collect{|arg|
      # arg will be fixed when arg = [index, value], otherwise pointer is newly made
      arg.kind_of?(Array) ? arg : [arg, get_ptr(args[arg])]
    }
    fname_new = fname.sub(/^./){$&.downcase}
    define_singleton_method(fname_new, proc{|*inputs|
      args_auto_buf.each{|arg| inputs.insert(arg[0], arg[1])}
      s = status(self.send(fname_orig, *inputs))
      raise [s, *inputs].inspect if :HID_SMBUS_SUCCESS != s
      args_auto.collect{|arg|
        arg.kind_of?(Array) ? nil : inputs[arg].to_value
      }.compact
    })
    if (:HID_SMBUS_DEVICE == args[0]) && (!args_auto.include?(0)) then
      Device.send(:define_method, fname_new, proc{|*args| CP2112::send(fname_new, @device, *args)})
    end
  }
  
  Device.send(:define_method, :initialize, proc{|*args| @device = CP2112::open(*args)[0]})
  
  class <<self
    def devices(vid = 0x0000, pid = 0x0000)
      getNumDevices(vid, pid)[0]
    end
    def [](index, vid = 0x0000, pid = 0x0000)
      lim = devices(vid, pid)
      raise "Incorrect index (must be < #{lim})" unless lim > index
      Device::new(index, vid, pid)
    end
  end
end
