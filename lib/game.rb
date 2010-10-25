require File.join(File.dirname(__FILE__), "board")

# A game is a board
#
# The game is created by the app. The game creates the board, performs updates
# for the app and updates the app.
#
#
class Game
  attr_reader :app, :board
  attr_accessor :score, :score_text

  def initialize(app)
    @app   = app

    setup_board

    # wait with setting up the score until the board has finished setup
    @score = 0
    @score_text = @app.para("Score: #{@score}", :top => 5, :left => 5)
  end

  # Make a nice little Board object
  #
  def setup_board
    @app.background @app.white
    @app.stroke @app.white
    @board = Board.new(self)
    @board.setup
  end

  # Update the game (ea; update the board)
  #
  def update
    board.update
  end

  # update the score and update the score text on the app
  #
  def update_score_by(amount)
    if score
      self.score = score + amount
    end
    if score_text
      self.score_text.replace "Score: #{score} - pieces left: #{@board.filled_pieces.count}"
    end
  end
end