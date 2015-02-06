# encoding: UTF-8
require 'yaml/store'
require 'fileutils'
require 'pathname'

class Minesweeper
  attr_accessor :board, :start_time, :game_time

  def dev_stuff
    self.start_time = Time.now
    mode = self.mode_select
    self.board = Board.new
    self.board.create_board_for_mode!(mode)
    self.game_time = Time.now - self.start_time
    high_scores
  end

  def run
    self.start_time = Time.now
    mode = self.mode_select
    if mode.between?(1,2)
      self.board = Board.new
      self.board.create_board_for_mode!(mode)
    else
      filename = ask_user_for_filename_to_load
      abort("No saved games.") if filename == ""
      file_contents = File.read(filename)
      other_minesweeper = YAML::load(file_contents)
      load_stuff_from_save_file(other_minesweeper)
    end

    until board.game_over?
      do_turn
    end
    self.game_time = Time.now - self.start_time
    if board.win?
      self.board.display_board
      puts "YOU ARE TEH WINNER!!"
      high_scores
    else
      self.board.display_board
      puts "FAIL, YOU DO NOT WIN"
    end
  end

  def high_scores
    case self.board.board.count
    when 9
      filename = '.high_scores_beginner.csv'
      pathname = Pathname.new(filename)
      if pathname.exist?
        high_score_list = File.readlines(filename).map(&:chomp)
      else
        FileUtils.touch(filename)
        high_score_list = []
      end
    when 16
      filename = '.high_scores_intermediate.csv'
      pathname = Pathname.new(filename)
      if pathname.exist?
        high_score_list = File.readlines(filename).map(&:chomp)
      else
        FileUtils.touch(filename)
        high_score_list = []
      end
    else
      "IF THIS SHOWS UP, BAD JUJU"
    end
    if high_score_list.count > 0
      worst_high_score = high_score_list.last.split(",")[1]
    else
      worst_high_score = 'Bad Badderston,9999999999999'
    end

    if high_score_list.count < 10 or self.game_time < worst_high_score
      users_name = get_users_name
      high_score_list << "#{users_name},#{self.game_time}"
    else
      puts "You completed the game in #{self.game_time} seconds!"
    end

    display_high_scores(high_score_list)
    # Debugging starts here
    high_score_list.sort! { |str| str.split(",")[0].to_f }.reverse[0..9]
    File.open(filename,'w') { |f| f.puts high_score_list.join("\n") }
  end

  def get_users_name
    puts "You got a high score with #{self.game_time} seconds!"
    print "Please enter your name: "
    gets.chomp
  end

  def display_high_scores(high_score_list)
    high_score_list.each_with_index do |line,index|
      name_time = line.split(',')
      puts "#{index + 1}: #{name_time[0]} - #{name_time[1]}"
    end
  end

  def ask_user_for_filename_to_load
    dirname = Dir.getwd
    if File.directory?("#{dirname}/saves/")
      files = Dir.entries("#{dirname}/saves/")
      input = 0
      files.reject! { |file| file[0] == '.' }

      until input.between?(1,files.length)
        files.each_with_index do |file,i|
          puts "#{i + 1}) #{file}"
        end
        print "Which file would you like to load? "
        input = gets.chomp.to_i
      end
      files.map! { |file| "#{dirname}/saves/#{file}"}

      return files[input - 1]
    else
      return ""
    end
  end

  def load_stuff_from_save_file(other_minesweeper)
    self.board = other_minesweeper.board
    self.game_time = other_minesweeper.game_time
    self.start_time = Time.now - self.game_time
  end

  def do_turn
    self.board.display_board
    move = get_move
    board.make_move(move)
  end

  def get_move
    input = ""
    until is_valid?(input)
      puts "Where would you like to move? '2 3 F' (row,col,action) [F for flag; P for probe]"
      puts "Enter: S 'filename' to save the game and exit."
      puts "Enter: Q to leave the game"
      input = gets.chomp.split(" ")
    end
    if input[0].upcase == 'S'
      save_and_exit(input[1])
    elsif input[0].upcase == 'Q'
      abort("Adios.")
    end

    input
  end

  def save_and_exit(filename)
    dir = "#{Dir.getwd}/saves"

    unless File.directory?(dir)
       FileUtils.mkdir_p(dir)
    end

    self.game_time = Time.now - self.start_time
    File.open("#{dir}/#{filename}",'w') { |f| f.write(self.to_yaml) }
    abort("Game Saved. Adios.")
  end

  def is_valid?(input)
    begin
      if input[0].upcase == 'S' or input[0].upcase == 'Q'
        return true
      end
      row = input[0].to_i
      col = input[1].to_i
      action = input[2].upcase

      board_length = self.board.board.count
      if (action == "F" or action == 'P') and row.between?(0,board_length) and col.between?(0,board_length)
        return true
      end
    rescue
    end

    false
  end

  def mode_select
    input = 0
    until input.between?(1,3)
      puts  '1) beginner'
      puts  '2) intermediate'
      puts  '3) load game from file'
      print 'what mode would you like to play? '
      input = gets.chomp.to_i
    end

    input
  end

end

class Board
  attr_accessor :board

  def create_board_for_mode!(mode)
    case mode
    when 1
      self.board = Array.new(9) { Array.new(9) {Square.new } }
      mines = (0..8).to_a.permutation(2).to_a.sample(10)
    when 2
      self.board = Array.new(16,) { Array.new(16) {Square.new } }
      mines = (0..15).to_a.permutation(2).to_a.sample(40)
    end

    mines.each do |mine|
      self.board[mine[0]][mine[1]].mine = true
    end

    number_the_squares!
  end

  def number_the_squares!
    0.upto(self.board.length-1) do |row|
      0.upto(self.board.length-1) do |col|
        mine_count = get_adj_mine_count(row,col)
        self.board[row][col].number = mine_count
      end
    end
  end

  def get_adj_mine_count(row,col)
    mine_count = 0
    [-1, 0, 1].each do |row_offset|
      [-1, 0, 1].each do |col_offset|
        if space_on_board?(row + row_offset, col + col_offset)
          mine_count += 1 if self.board[row + row_offset][col + col_offset].mine
        end
      end
    end

    mine_count
  end

  def get_adj_squares(row,col)
    squares = []
    [-1, 0, 1].each do |row_offset|
      [-1, 0, 1].each do |col_offset|
        if [row_offset, col_offset] != [0, 0] and space_on_board?(row + row_offset, col + col_offset)
          squares << [row + row_offset, col + col_offset]
        end
      end
    end

    squares
  end


  def space_is_empty?(row, col)
    not self.board[row][col].mine
  end

  def space_on_board?(row, col)
    row.between?(0, self.board.length - 1) and col.between?(0, self.board.length - 1)
  end

  def dev_display_board
    puts " " + ("-" * (self.board.length * 4 - 1))
    self.board.each do |row|
      print '|'
      row.each do |square|
        if square.mine
          print ' ▓ |'
        elsif square.number == 0
          print '   |'
        else
          print " #{square.number} |"
        end
      end
      puts ''
    puts " " + ("-" * (self.board.length * 4 - 1))
    end
  end

  def display_board
    puts " " + ("-" * (self.board.length * 4 - 1))
    self.board.each do |row|
      print '|'
      row.each do |square|
        if square.visible
          if square.mine
            print ' * |'
          elsif square.number == 0
            print '   |'
          else
            print " #{square.number} |"
          end
        else
          if square.flagged
            print ' ⚑ |'
          elsif
            print ' ▓ |'
          end
        end
      end
      puts ''
      puts " " + ("-" * (self.board.length * 4 - 1))
    end
  end

  def make_move(move)
    row = move[0].to_i
    col = move[1].to_i
    case move[2]
    when 'P'
      if self.board[row][col].mine == true
        self.board[row][col].visible = true
      elsif self.board[row][col].number != 0
        self.board[row][col].visible = true
      else
        exploderate(row,col)
      end
    when 'F'
      self.board[row][col].flagged = !self.board[row][col].flagged
    end
  end

  def exploderate(row,col)
    adj_sqrs = get_adj_squares(row,col)
    adj_sqrs.each do |coord|
      if self.board[coord[0]][coord[1]].number == 0 and self.board[coord[0]][coord[1]].visible == false
        self.board[coord[0]][coord[1]].visible = true
        exploderate(coord[0], coord[1])
      else
        self.board[coord[0]][coord[1]].visible = true
      end
    end
  end

  def win?
    self.board.each do |row|
      row.each do |square|
        if square.mine == false and square.visible == false
          return false
        end
      end
    end

    true
  end

  def lose?
    self.board.each do |row|
      row.each do |square|
        if square.mine == true and square.visible == true
          return true
        end
      end
    end

    false
  end

  def game_over?
    win? or lose?
  end
end

class Square
  attr_accessor :visible, :flagged, :mine, :number

  def initialize
    self.visible = false
    self.flagged = false
    self.mine = false
    self.number = 0
  end

end

if __FILE__ == $0
  m = Minesweeper.new.dev_stuff
end
