$rom = $gtk.read_file('roms/space_invaders.ch8').bytes
#$rom = $dragon.ffi_file.loadfile('roms/pong.ch8').bytes
#$rom = $dragon.ffi_file.loadfile('roms/breakout.ch8').bytes
#$rom = $dragon.ffi_file.loadfile('roms/maze.ch8').bytes
#$rom = $dragon.ffi_file.loadfile('roms/brix.ch8').bytes


class Chip8
  attr_accessor :game, :inputs, :outputs
  def initialize
    @ram = Array.new(4096, 0)
    @pc = 0x200
    @ram[@pc, $rom.length] = $rom
    @ram[0,5] = [0xF0, 0x90, 0x90, 0x90, 0xF0] # digit zero
    @ram[1*5,5] = [0x20, 0x60, 0x20, 0x20, 0x70] # digit one
    @ram[2*5,5] = [0xF0, 0x10, 0xF0, 0x80, 0xF0] # digit two
    @ram[3*5,5] = [0xF0, 0x10, 0xF0, 0x10, 0xF0] # digit three
    @ram[4*5,5] = [0x90, 0x90, 0xF0, 0x10, 0x10] # digit four
    @ram[5*5,5] = [0xF0, 0x80, 0xF0, 0x10, 0xF0] # digit five
    @ram[6*5,5] = [0xF0, 0x80, 0xF0, 0x90, 0xF0] # digit six
    @ram[7*5,5] = [0xF0, 0x10, 0x20, 0x40, 0x40] # digit seven
    @ram[8*5,5] = [0xF0, 0x90, 0xF0, 0x90, 0xF0] # digit eight
    @ram[9*5,5] = [0xF0, 0x90, 0xF0, 0x10, 0xF0] # digit nine
    @ram[10*5,5] = [0xF0, 0x90, 0xF0, 0x90, 0x90] # digit A
    @ram[11*5,5] = [0xE0, 0x90, 0xE0, 0x90, 0xE0] # digit B
    @ram[12*5,5] = [0xF0, 0x80, 0x80, 0x80, 0xF0] # digit C
    @ram[13*5,5] = [0xE0, 0x90, 0x90, 0x90, 0xE0] # digit D
    @ram[14*5,5] = [0xF0, 0x80, 0xF0, 0x80, 0xF0] # digit E
    @ram[15*5,5] = [0xF0, 0x80, 0xF0, 0x80, 0x80] # digit F
    @sp = 0
    @i = 0
    @dt = 0
    @st = 0
    @stack = Array.new(16, 0)
    @display = Array.new(2048, 0)
    @registers = Array.new(16, 0)
    @keymap = %i{x one two three q w e a s d z c four r f v}
    puts $rom.map { |op| "%02X" % op }
  end

  def opx
    (@opcode & 0x0F00) >> 8
  end

  def opy
    (@opcode & 0x00F0) >> 4
  end

  def opkk
    @opcode & 0x00FF
  end

  def opnnn
    @opcode & 0x0FFF
  end

  def handle_timers
    @dt -= 1 unless @dt == 0
    @st -= 1 unless @st == 0
    outputs.sounds << 'sounds/beep.wav' if @st == 1
  end

  def fetch_opcode
    a, b = @ram[@pc, 2]
    @opcode = (a << 8) | b
    @pc += 2
  end

  def clear_screen
    @display = Array.new(@display.length, 0)
  end

  def ret
    @pc = @stack[@sp]
    @sp -= 1 unless @sp == 0
  end

  def jmp1
    @pc = opnnn
  end

  def call_subroutine
    @sp += 1
    @stack[@sp] = @pc
    @pc = opnnn
  end

  def se3
    @pc += 2 if @registers[opx] == opkk
  end

  def sne
    @pc += 2 if @registers[opx] != opkk
  end

  def se5
    @pc += 2 if @registers[opx] == @registers[opy]
  end

  def ld6
    @registers[opx] = opkk
  end

  def add7
    @registers[opx] += opkk
    @registers[opx] = @registers[opx] & 0xFF
  end

  def ld8
    @registers[opx] = @registers[opy]
  end

  def or8
    @registers[opx] |= @registers[opy]
  end

  def and8
    @registers[opx] &= @registers[opy]
  end

  def xor8
    @registers[opx] ^= @registers[opy]
  end

  def add8
    result = @registers[opx] + @registers[opy]
    @registers[0xF] = result > 255 ? 1 : 0
    @registers[opx] = result & 0xFF
  end

  def sub8
    borrow = @registers[opx] > @registers[opy]
    @registers[0xF] = borrow ? 1 : 0
    @registers[opx] -= @registers[opy]
    @registers[opx] = @registers[opx] & 0xFF
  end

  def shr8
    @registers[0xF] = @registers[opx] & 0x000F ^ 0x0001 == 0 ? 1 : 0
    @registers[opx] = @registers[opx].div(2)
  end

  def subn8
    not_borrow = @registers[opx] < @registers[opy]
    @registers[0xF] = not_borrow ? 1 : 0
    @registers[opx] = (@registers[opy] - @registers[opx]) & 0xFF
  end

  def shl8
    @registers[0xF] = @registers[opx] & 0xF000 ^ 0x1000 ? 1 : 0
    @registers[opx] *= 2
  end

  def sne9
    @pc += 2 if @registers[opx] != @registers[opy]
  end

  def ldi
    @i = opnnn
  end

  def jmpb
    @pc = opnnn + @registers[0]
  end

  def rnd
    @registers[opx] = rand(256) & (opkk)
  end

  def skp
    key = @registers[opx] & 0xF
    @pc += 2 if inputs.keyboard.key_held.send(@keymap[key])
  end

  def sknp
    key = @registers[opx] & 0xF
    @pc += 2 unless inputs.keyboard.key_held.send(@keymap[key])
  end

  def ldfx07
    @registers[opx] = @dt
  end

  def ldfx0a
    @blocked = true
    key_state = @keymap.map { |key| inputs.keyboard.key_held.send(key) }
    if key_state.index(true)
      @blocked = false
      @registers[opx] = key_state.index(true)
    end
  end
  
  def ldfx15
    @dt = @registers[opx]
  end

  def ldfx18
    @st = @registers[opx]
  end

  def addfx1e
    @i += @registers[opx]
    @i = @i & 0xFFFF
  end

  def ldfx29
    @i = @registers[opx] * 5
  end

  def ldfx33
    value = @registers[opx]
    @ram[@i] = value.div(100) % 10
    @ram[@i + 1] = value.div(10) % 10
    @ram[@i + 2] = value % 10
  end

  def ldfx55
    @ram[@i,opx+1] = @registers[0..opx]
  end

  def ldfx65
    @registers[0..opx] = @ram[@i,opx+1]
  end

  def drw
    x, y = @registers[opx], @registers[opy]
    n = @opcode & 0x000F
    collision_occurred = false
    n.times do |row|
      current_sprite_byte = @ram[@i+row]
      8.times do |bit|
        current_pixel = @display[(x+bit) + (y+row)*64]
        new_pixel = current_sprite_byte & (0x80 >> bit) != 0 ? 1 : 0
        unless collision_occurred
          collision_occurred = true if current_pixel == 1 && new_pixel == 0
        end
        @display[(x+bit) + (y+row)*64] = current_pixel ^ new_pixel
      end
    end
    @registers[0xF] = collision_occurred ? 1 : 0
  end

  def debug_display
    output = ""
    32.times do |y|
      output += "#{@display[y*64,64].join('')}\n"
    end
    puts output
  end

  def parse_opcode
    if @opcode == 0x00E0
      clear_screen
    elsif @opcode == 0x00EE
      ret
    elsif @opcode & 0xF000 ^ 0x1000 == 0
      jmp1
    elsif @opcode & 0xF000 ^ 0x2000 == 0
      call_subroutine
    elsif @opcode & 0xF000 ^ 0x3000 == 0
      se3
    elsif @opcode & 0xF000 ^ 0x4000 == 0
      sne
    elsif @opcode & 0xF00F ^ 0x5000 == 0
      se5
    elsif @opcode & 0xF000 ^ 0x6000 == 0
      ld6
    elsif @opcode & 0xF000 ^ 0x7000 == 0
      add7
    elsif @opcode & 0xF00F ^ 0x8000 == 0
      ld8
    elsif @opcode & 0xF00F ^ 0x8001 == 0
      or8
    elsif @opcode & 0xF00F ^ 0x8002 == 0
      and8
    elsif @opcode & 0xF00F ^ 0x8003 == 0
      xor8
    elsif @opcode & 0xF00F ^ 0x8004 == 0
      add8
    elsif @opcode & 0xF00F ^ 0x8005 == 0
      sub8
    elsif @opcode & 0xF00F ^ 0x8006 == 0
      shr8
    elsif @opcode & 0xF00F ^ 0x8007 == 0
      subn8
    elsif @opcode & 0xF00F ^ 0x800E == 0
      shl8
    elsif @opcode & 0xF00F ^ 0x9000 == 0
      sne9
    elsif @opcode & 0xF000 ^ 0xA000 == 0
      ldi
    elsif @opcode & 0xF000 ^ 0xB000 == 0
      jmpb
    elsif @opcode & 0xF000 ^ 0xC000 == 0
      rnd
    elsif @opcode & 0xF000 ^ 0xD000 == 0
      drw
    elsif @opcode & 0xF0FF ^ 0xE09E == 0
      skp
    elsif @opcode & 0xF0FF ^ 0xE0A1 == 0
      sknp
    elsif @opcode & 0xF0FF ^ 0xF007 == 0
      ldfx07
    elsif @opcode & 0xF0FF ^ 0xF00A == 0
      ldfx0a
    elsif @opcode & 0xF0FF ^ 0xF015 == 0
      ldfx15
    elsif @opcode & 0xF0FF ^ 0xF018 == 0
      ldfx18
    elsif @opcode & 0xF0FF ^ 0xF01E == 0
      addfx1e
    elsif @opcode & 0xF0FF ^ 0xF029 == 0
      ldfx29
    elsif @opcode & 0xF0FF ^ 0xF033 == 0
      ldfx33
    elsif @opcode & 0xF0FF ^ 0xF055 == 0
      ldfx55
    elsif @opcode & 0xF0FF ^ 0xF065 == 0
      ldfx65
    else
      puts "INVALID OPCODE: 0x#{@opcode.to_s(16)}"
      @halt = true
    end
  end

  def render
    pixel_w = 20
    pixel_h = 22
    @display.each_with_index do |pixel, i|
      outputs.solids << [(i % 64) * pixel_w, (720 - pixel_h - 8) - i.div(64) * pixel_h, pixel_w, pixel_h, 255, 255, 255, 255] if pixel == 1
    end
  end

  def tick
    if @blocked
      ldfx0a
    elsif @halt
      unless @finished_halting
        puts 'Program Halted'
        puts "@pc #{@pc}"
        puts "@opcode #{@opcode.to_s(16)}"
        puts "@i #{@i}"
        puts @registers
	debug_display
        puts outputs.solids
        @finished_halting = true
      end
    else
      handle_timers
      game.speed.times do
        fetch_opcode
        parse_opcode
      end

      if inputs.keyboard.key_down.zero
        game.speed += 1
        puts "Game speed: #{game.speed}"
      end

      if inputs.keyboard.key_down.nine
        game.speed -= 1
        puts "Game speed: #{game.speed}"
      end
      game.speed = 0 if game.speed < 0
      # puts "#{'%04X' % @opcode} #{@pc} #{@i} #{@registers.join(' ')} STACK: #{@stack.join(' ')}"
    end
    render
  end
end

$chip8 = Chip8.new
def tick args
  game, grid, inputs, outputs = args.state, args.grid, args.inputs, args.outputs
  $chip8.inputs = inputs
  $chip8.outputs = outputs
  $chip8.game = game
  game.speed ||= 1
  args.dragon.reset if inputs.keyboard.key_up.enter
  args.dragon.gridlines! if inputs.keyboard.key_up.tab
  outputs.solids << [grid.rect, [0*3]]
  $chip8.tick
end
