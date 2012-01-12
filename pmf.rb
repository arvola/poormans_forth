#!/usr/bin/env ruby

# Poor Man's Forth
# http://puzzlenode.com/puzzles/24
#
# Copyright:: 2011 Eddie the Esoteric Programmer
# Author:: Mikael Arvola

@var_stack = []
@commands = {}
@procedures = {}


# Classes primarily for identification and container purposes.
# They do not take care of running what they have

class Ifelse
  attr_accessor :true, :false

  def initialize yes, no
    @true = yes
    @false = no
  end
end
class Times
  attr_accessor :block, :num

  def initialize block
    @block = block
  end
end
class Procedure
  attr_accessor :block

  def initialize
    @block = nil
  end
end


# "Built-in" syntax

@commands.store("DUP", Proc.new do
  @var_stack.push @var_stack.last()
end)

@commands.store("SWAP", Proc.new do
  @var_stack.push @var_stack.slice!(-2)
end)

@commands.store("SUBTRACT", Proc.new do
  @var_stack.push((@var_stack.pop * -1) + @var_stack.pop)
end)

@commands.store("ROT", Proc.new do
  @var_stack.push @var_stack.slice! -3
end)

@commands.store("MOD", Proc.new do
  @var_stack.push((@var_stack.slice!(-2)) % @var_stack.pop)
end)

@commands.store("=", Proc.new do
  @var_stack.push(@var_stack.pop == @var_stack.pop)
end)


# The compiler itself
#
# Compiles the script into Ruby instructions
def compile script
  compiled = []
  while script.count > 0
    line = script.shift.strip

    # Flow structures
    if line == "IF"
      n = 0
      index = 0
      else_index = 0
      depth = 0
      script.each do |v|
        v.strip!
        if v == "THEN" && depth == 0
          index = n
          break
        elsif v == "ELSE" && depth == 0
          else_index = n
        elsif v == "THEN" && depth > 0
          depth -= 1
        elsif v == "IF"
          depth += 1
        end
        n += 1
      end
      raise Exception.new("Syntax error") unless index
      block = script.shift(index+1)
      # Get rid of the THEN
      block.pop
      if else_index > 0
        yes = block.shift(else_index)
        # Ignore the ELSE word
        no = block[1..-1]
      else
        yes = block
        no = nil
      end
      compiled << Ifelse.new(compile(yes), compile(no))

    elsif line == "TIMES"
      n = script.index { |v| v.strip == "/TIMES" }
      raise Exception.new("Syntax error") unless n
      block = script.shift(n+1)
      # Get rid of the /TIMES
      block.pop
      compiled << Times.new(compile(block))

    elsif /PROCEDURE\s+(?<name>[A-Za-z0-9_-]+)/ =~ line
      # Populate first so that the procedure can call itself
      @procedures[name] = Procedure.new
      n = script.index { |v| v.strip == "/PROCEDURE" }
      raise Exception.new("Syntax error") unless n
      block = script.shift(n+1)
      # Get rid of the /PROCEDURE
      block.pop
      @procedures[name].block = compile(block)

    elsif @commands.has_key? line
      compiled << @commands[line]

    elsif @procedures.has_key? line
      compiled << @procedures[line]

      # Only need to account for integers
    elsif /^[0-9]+$/ =~ line
      compiled << line.to_i

      # Literal
    elsif !line.empty?
      compiled << line

    end
  end
  compiled
end


# Runner to run through the quasi-intermediary instruction list
def run_compiled compiled
  compiled.each do |v|
    if v.is_a? Numeric
      @var_stack.push v
    elsif v.is_a? Procedure
      run_compiled v.block
    elsif v.is_a? Times
      @var_stack.pop.times do
        run_compiled v.block
      end
    elsif v.is_a? Ifelse
      if @var_stack.pop.is_a? TrueClass
        run_compiled v.true
      elsif !v.false.nil?
        run_compiled v.false
      end
    elsif v.is_a? Proc
      v.call
    else
      v.is_a? String
      @var_stack.push v
    end
  end
end

# Expects an array of lines
def interpret script
  compiled = compile script
  run_compiled compiled
end


if ARGV.length < 1
  puts "One argument required: script file to run"
  exit
end

file = ARGV[0]

unless FileTest.exists?(file)
  puts "File not found, exiting."
  exit
end

script = File.open(file, 'rb') { |f| f.readlines }
begin
  interpret(script)
rescue Exception
  puts "Error! Error!"
  puts $!.message
  puts $!.backtrace
end

# It's a stack, so reverse for puts
puts @var_stack.reverse
