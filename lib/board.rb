require File.join(File.dirname(__FILE__), "piece")

class Board
  WIDTH  = 12
  HEIGHT = 14

  CLUSTER_SIZE = 2

  attr_reader :game, :width, :height

  def initialize(game, width=WIDTH, height=HEIGHT)
    @game   = game
    @width  = width
    @height = height
  end

  def setup
    setup_pieces

    if !moves_left?
      @pieces = nil
      setup_pieces
    end

    init_listeners

    draw
  end

  # place new pieces in an array of columns and rows on the board
  #
  # make sure there are no matches and there are moves left
  #
  def setup_pieces
    $stderr.puts "Setting up pieces"
    @pieces ||= Array.new(width) { Array.new(height) { nil } }

    # fill empty slots with new pieces
    @pieces.each_index { |col|
      @pieces[col].each_index { |row|
        @pieces[col][row] ||= Piece.new(self, col, row)
      }
    }

    register_neighbours
  end

  def register_neighbours
    filled_pieces.each { |piece| piece.register_neighbours }
  end

  # set up listeners
  #
  def init_listeners
    game.app.click do |button, x, y|
      if button != 1
        piece = filled_pieces.select { |piece| piece.placed_on?(x,y) }.first
        $stderr.puts piece.hood.collect { |p,b| "#{p}: #{b.color rescue "-"}" }
      else
        if selected.empty?
          # when no piece is selected, select one
          select(x,y)

        else
          # otherwise; swap the pieces if they are adjecent,
          # select a new piece if not
          #
          other = filled_pieces.select { |piece| piece.placed_on?(x,y) }.first
          if selected.include? other
            selected.each { |sel| sel.mark }

          else
            select(x,y)
          end
        end
      end
    end
  end

  # Update the pieces on the board
  #
  # + When there are moveable pieces, move them
  # + When there are matches, clear them
  # + When there are empty pieces, drop in new ones.
  # + Check if there are moves left
  # + Redraw the board
  #
  def update
    if moveable_pieces?
      move_pieces 
      register_neigbours if !moveable_pieces
      
    elsif marked_pieces?
      clear_matches
      shift_pieces
      @check_moves = true

    elsif @check_moves == true
      moves_left?
      @check_moves = false
      
    end
  end

  # return all the pieces on the board as a single array
  #
  def pieces
    @pieces
  end

  def filled_pieces
    pieces.flatten.select { |p| p.is_a? Piece }
  end

  # draw the board (that is let each piece draw)
  #
  def draw
    filled_pieces.each { |piece| piece.draw }
  end

  # call redraw on each of the places and pieces
  #
  def redraw
    filled_pieces.each { |piece| piece.redraw }
  end

  # select a piece for the next move and make it selected
  #
  # Also; unselect the currently selected piece
  #
  def select(x,y)
    if ( old = selected )
      old.each { |piece| piece.unselect; piece.redraw }
    end

    selected = self.filled_pieces.select { |p| p.placed_on?(x,y) }.first

    # we need some pieces for a match
    cluster = get_cluster(selected)
    if cluster.count >= CLUSTER_SIZE
      cluster.each { |piece| piece.select }
      return true
    end

    return false
  end

  # return the selected pieces
  #
  def selected
    self.filled_pieces.select { |piece| piece.selected? }
  end

  # get the cluster surrounding the given piece
  #
  def get_cluster(piece)
    return [] if piece.nil?
    piece.hood.inject([]) do |cluster, (position, neighbour)|
      cluster = ( neighbour.nil? ?
        cluster :
        piece =~ neighbour ?
          cluster + find_cluster(neighbour, piece, cluster) :
          cluster
      )
    end
  end

  # recurse all the neighbours around the piece and fill the given cluster
  #
  def find_cluster(piece, previous=nil, cluster=[], depth = 0)
    # return cluster.uniq if depth == 20
    cluster << piece    unless cluster.include? piece
    cluster << previous unless cluster.include? previous
    
    piece.hood.each { |position, neighbour|
      next if neighbour.nil?
      next if previous and previous == neighbour
      next if cluster.include? neighbour

      if neighbour =~ piece
        cluster += find_cluster(neighbour, piece, cluster, depth + 1)
      end
      
    }

    return cluster
  end

  # clear any matching pieces (after moving was performed)
  #
  # For each cleared piece update the score
  #
  def clear_matches
    # let the moves take place first
    return if moveable_pieces?
    return if !marked_pieces?

    amount = marked_pieces.count

    marked_pieces.each { |piece|
      if piece and piece.marked?
        piece.remove
        piece.unregister
        
        game.update_score_by( piece.marked * ( 5 * amount ) )
        pieces[piece.x][piece.y] = nil
      end
    }
  end

  # Shift pieces down and to the right when there is a opening
  #
  def shift_pieces
    # let the moves unfold
    return if moveable_pieces?
    return if marked_pieces?

    pieces.each_index { |col|
      next if pieces[col].nil?
      # when the entire row is empty, shift all left rows right
      if col > 0 and pieces[col].select { |row| row.is_a? Piece }.empty?
        col.downto(1) do |i|
          if pieces[i-1].nil?
            pieces[i] = nil
            next
          end
          
          pieces[i] = pieces[i-1].clone
          pieces[i-1] = nil
          pieces[i].each_index { |row|
            next if pieces[i][row].nil?
            pieces[i][row].index = [i, row]
          }
        end
      end
      
      next if pieces[col].nil?

      pieces[col].each_index { |row|
        next if row == HEIGHT - 1
        piece = pieces[col][row]
        next if piece.nil?
        
        # when there is no bottom neighbour, drop this piece and
        # all the pieces above it
        #
        dist = 0
        if piece and pieces[col][row+1].nil?
          (row+1).upto(pieces[col].length) do |i|
            if pieces[col][i].nil?
              dist = dist + 1
            else
              break
            end
          end

          movers = []
          row.downto(0) do |i|
            next if pieces[col][i].nil?
            movers << pieces[col][i]
          end

          movers.each { |drop|
            while (drop.y + dist) > pieces[col].length - 1
              dist -= 1
            end

            pieces[drop.x][drop.y] = nil
            pieces[drop.x][drop.y + dist] = drop
            drop.index = [ drop.x, drop.y + dist ]
          }
        end
      }
    }

    # redraw
    register_neighbours
  end

  # move all the pieces into their required position
  #
  def move_pieces
    moveable_pieces.each { |piece|
      piece.move
    }
  end

  # get all the pieces that are moveable
  #
  def moveable_pieces
    filled_pieces.select { |piece| piece and piece.moveable? }
  end

  # are there any moveable pieces?
  #
  def moveable_pieces?
    !moveable_pieces.empty?
  end

  # get all the pieces that are marked
  #
  def marked_pieces
    filled_pieces.select { |piece| piece and piece.marked? }
  end

  # are there any marked pieces?
  #
  def marked_pieces?
    !marked_pieces.empty?
  end

  # Are there any moves left?
  #
  def moves_left?
    if filled_pieces.empty?
      game.app.alert "You rock!"
      game.app.exit
      return
    end

    filled_pieces.each do |piece|
      piece.hood.each { |pos, neighbour|
        return true if piece =~ neighbour
      }
    end

    game.app.alert "No more moves..."
    game.app.exit
  end
end