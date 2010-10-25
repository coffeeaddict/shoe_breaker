require File.join(File.dirname(__FILE__), "game")

Shoes.app(
  :title  => "Shoebreaker (need wooden shoes for that...)",
  :width  => ( Board::WIDTH + 2  ) * Piece::SIZE,
  :height => ( Board::HEIGHT + 2 ) * Piece::SIZE + Piece::SIZE
) do

  game = Game.new(self)
  @anim = animate do
    game.update
  end
end