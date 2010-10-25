# Monkey patch for 'inverting' symbols
class Symbol
  def invert
    case self
    when :top; :bottom
    when :bottom; :top
    when :right; :left
    when :left; :right
    end
  end
end

# A piece has a color and a X & Y position on the board
#
# A piece might be marked or selected
#
class Piece
  COLORS = [
    "red", "blue", "green", "yellow", "purple" # , "pink", "magenta", "cyan", "orange"
  ]
  SIZE    = 21
  DIST    = 7

  attr_reader :board, :color, :shape, :marked, :selected, :neighbour
  attr_accessor :index

  def initialize(board, x, y, color=nil)
    @board     = board
    @color     = color || COLORS[rand(COLORS.length)]
    @index     = [x, y]
    @marked    = 0
    @selected  = false
    @neighbour = {}
    
    register_neighbours
  end

  # remove and then draw
  #
  def redraw
    remove if self.shape
    draw
  end

  # remove the shape from the app
  #
  def remove
    self.shape.remove
  rescue
  end

  # draw a shape on the app
  #
  def draw()
    (x, y) = index
    app.stroke(selected? ? app.black : app.white)
    app.fill(app.send(color))
    @shape = app.oval(x_pos, y_pos, SIZE)
  end

  # Is the piece placed on this position?
  #
  def placed_on?(x_pos,y_pos)
    x = ( ( x_pos - SIZE ) / SIZE )
    y = ( ( y_pos - SIZE * 2 ) / SIZE )

    [x,y] == index
  end

  # mark the piece for removal
  #
  def mark
    @marked += 1
  end

  # umark the piece
  #
  def unmark
    @marked = 0
  end

  # is the piece marked?
  #
  def marked?
    @marked > 0 ? true : false
  end

  # select the piece
  #
  def select
    @selected = true
    redraw
  end

  # unselect the piece
  #
  def unselect
    @selected = false
  end

  # Is the piece selected?
  #
  def selected?
    @selected == true ? true : false
  end

  # A link to the board, to the game to the app
  #
  def app
    board.game.app
  end

  # move the Shoes#shape until top and left match the x and y position
  # on the board
  #
  def move
    top  = shape.style[:top]
    left = shape.style[:left]

    dir_y = top < y_pos ? DIST : top == y_pos ? 0 : 0-DIST
    dir_x = left < x_pos ? DIST : left == x_pos ? 0 : 0-DIST

    self.shape.move(left + dir_x, top + dir_y)
  end

  # is the Shoes#shape top not on the y_pos and and the left not on the y_pos
  # then the piece is moveable
  #
  def moveable?
    return !( shape.style[:top] == y_pos and shape.style[:left] == x_pos )
  rescue
    false
  end

  # The x position on the board
  def x
    index[0]
  end

  # the y position on the board
  def y
    index[1]
  end

  # the x position on the app
  def x_pos
    SIZE + ( SIZE * index[0] )
  end

  # the y position on the app
  def y_pos
    SIZE * 2 + ( SIZE * index[1] )
  end

  # unregister the piece from it's neighbourhood
  #
  def unregister
    hood.each { |pos, neighbour|
      neighbour.register_neighbour(pos.invert, nil) unless neighbour.nil?
    }
    board.pieces[x][y] = nil
  end

  # register all the neigbours given the board
  #
  def register_neighbours
    register_neighbour(:top,    (board.pieces[x][y-1] rescue nil)) unless y == 1
    register_neighbour(:left,   (board.pieces[x-1][y] rescue nil)) unless x == 1
    register_neighbour(:bottom, (board.pieces[x][y+1] rescue nil)) if y < board.height
    register_neighbour(:right,  (board.pieces[x+1][y] rescue nil)) if x < board.width
  end

  # register a neighbour
  #
  # == where
  # [:top]     The upstairs neighbour
  # [:bottom]  The downstairs neighbour
  # [:left]    The neighbour at nr 1
  # [:right]   The neighbour at nr 3
  #
  # == who
  # The neighbour (again!)
  #
  def register_neighbour(where, who)
    unless [:top, :bottom, :left, :right].include? where
      $stderr.puts "Cannot register a neighbour at #{where}"
    end

    # prevent endless recursion - dont double register
    return if @neighbour[where] == who

    # we can't be neighbours - we're to far apart!
    return if who.is_a? Piece and ( ((who.x + who.y) - (self.x + self.y)).abs > 1 )

    @neighbour[where] = who
    who.register_neighbour(where.invert, self) if who.is_a? Piece
  end

  # register the neighbours in one go
  def neighbourhood
    @neighbour
  end
  alias_method :hood, :neighbourhood

  # set the entire hood in one go
  def hood=(hash)
    @neighbour = hash
  end

  # are the pieces of the same color?
  def =~(other)
    self.color == other.color rescue false
  end
end
