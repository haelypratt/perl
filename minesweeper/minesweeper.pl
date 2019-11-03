#!/usr/bin/env perl

use strict; use warnings;
use List::Util qw/ shuffle min max /;
use Tk; use Tk::PNG; use Tk::Dialog;
use Class::Struct;

# Variables ##############################################################################

use vars qw/ $remainingCells $remainingMines $flagsPlaced $firstClick /; # Game State data
use vars qw/ @board $height $width $numMines @mineCells /;               # Board data
struct Cell => {                                                         # Cell data
  state => '$',     # -1 => revealed, 0 => hidden, 1 => flagged
  value => '$',     # -1 => mine, or number of mine neighbors {0, ..., 8}
  widget => '$'     # cell button or label
};

# Constants ##############################################################################

use constant {
  windowBG => '#94bdff', buttonBG => '#215fc6', buttonActiveBG => '#4f8eff',
  labelBG  => '#cbe0ff', mineBG   => '#c12f33'
};

# Images #################################################################################

my $imdir = 'img';
unless(-d $imdir){ $0 =~ s!^.*/!!; die "$0:\nImage directory `$imdir' does not exist\n"; }

my %img = (
  0 => {file => '0'}, 1 => {file => '1'}, 2 => {file => '2'}, 3 => {file => '3'},
  4 => {file => '4'}, 5 => {file => '5'}, 6 => {file => '6'}, 7 => {file => '7'},
  8 => {file => '8'}, mine => {file => 'mine'}, flag => {file => 'flag'}
);

# Main Window ############################################################################

my $mainWindow = MainWindow->new(-title => 'Minesweeper', -background => &windowBG);
# $mainWindow->resizable(0,0); # Removed due to bug in Windows 10

# Menu
my $menu = $mainWindow->Menu;
$menu->cascade(
  -label => 'Game', -tearoff => 0,
  -menuitems => [
    [command => 'Restart',                -command => [\&restart_game]],
    '',
    [command => 'New Beginner Game',      -command => [\&init_game, 9, 9, 10]],
    [command => 'New Intermediate Game',  -command => [\&init_game, 16, 16, 40]],
    [command => 'New Advanced Game',      -command => [\&init_game, 16, 30, 99]],
    [command => 'New Custom Game',        -command => [\&custom_game]],
    '',
    [command => '~Quit', -command => sub{ exit }]
  ]
);
$mainWindow->configure(-menu => $menu);

# Initialize image widgets
foreach my $k (keys %img){
  my $f = $img{$k}{'file'}; $f = "$imdir/$f.png";
  $img{$k}{'photo'} = $mainWindow->Photo(-file => $f);
}

# Display frames
my $statsFrame = $mainWindow->Frame(-background => &windowBG);
$statsFrame->pack(-side => 'top', -fill => 'x', -expand => '1');

my $mineLabel = $statsFrame->Label(-background => &windowBG, -height => 1)->grid(
  -row => 0, -column => 0, -sticky => 'nesw', -ipadx => 4, -ipady => 4);
$mineLabel->configure(-image => $img{'mine'}{'photo'});

my $mineCount = $statsFrame->Label(-background => &windowBG, -height => 1)->grid(
  -row => 0, -column => 1, -sticky => 'nesw', -ipadx => 4, -ipady => 4);
$mineCount->configure(-text => '0', -font => ['arial',12,'bold']);

my $boardFrame = $mainWindow->Frame(-background => &windowBG, -relief => 'sunken',
  -borderwidth => 3);
$boardFrame->pack(-side => 'bottom', -expand => '1', -padx => 10, -pady => 10);

# Default to beginner game
init_game(9,9,10);

MainLoop;

# Subroutines ############################################################################

#-----------------------------------------------------------------------------------------
# Creates a custom board.
#-----------------------------------------------------------------------------------------

sub custom_game {
  my ($h, $w, $m, $maxMines);
  
  # Initial settings (height, width, mines, & maximum number of mines)
  $h = $height; $w = $width; $m = $numMines; $maxMines = ($h-1)*($w-1);
  
  # Dialog box
  my $db = $mainWindow->DialogBox(-title => 'Game Settings', -buttons => ['OK','Cancel']);
  
  # Dialog labels
  $db->add('Label', -font => ['arial',9,'bold'], -text => 'Height (8 - 24):')->grid(
    -row => 0, -column => 0, -ipadx => 5, -ipady => 5, -sticky => 'w');
  $db->add('Label', -font => ['arial',9,'bold'], -text => 'Width (8 - 30):')->grid(
    -row => 1, -column => 0, -ipadx => 5, -ipady => 5, -sticky => 'w');
  $db->add('Label', -font => ['arial',9,'bold'], -text => 'Mines (10 - ?):')->grid(
    -row => 2, -column => 0, -ipadx => 5, -ipady => 5, -sticky => 'w');
  
  # Input Sliders
  my $mineSlider = $db->add('Scale', -font => ['arial',9,'bold'], -variable => \$m,
    -from => 10, -to => $maxMines, -length => 150, -sliderlength => 10, -showvalue => 1,
    -orient => 'horizontal')->grid(-row => 2, -column => 1);
  
  my $update_max_mines = sub{
    $maxMines = ($h-1)*($w-1);
    $mineSlider->configure(-to => $maxMines);
  };
  
  $db->add('Scale', -font => ['arial',9,'bold'], -variable => \$h,
    -from => 8, -to => 24, -length => 150, -sliderlength => 10, -showvalue => 1,
    -orient => 'horizontal', -command => \$update_max_mines
  )->grid(-row => 0, -column => 1);
  
  $db->add('Scale', -font => ['arial',9,'bold'], -variable => \$w,
    -from => 8, -to => 30, -length => 150, -sliderlength => 10, -showvalue => 1,
    -orient => 'horizontal', -command => \$update_max_mines
  )->grid(-row => 1, -column => 1);
  
  # Show dialog and initialize new game with user settings
  my $response = $db->Show(-popover => $mainWindow);
  if($response and $response eq 'OK'){ init_game($h,$w,$m); }
}

#-----------------------------------------------------------------------------------------
# Initializes a new game
#-----------------------------------------------------------------------------------------

sub init_game {
  # Remove any widgets from the previous game and create an empty board
  if($boardFrame->children){foreach my $w ($boardFrame->children){ $w->destroy; }}
  @board = ();
  
  # Initialize new game settings
  $height = shift; $width = shift; $numMines = shift;
  $remainingCells = $height * $width - $numMines;
  $remainingMines = $numMines;
  $flagsPlaced = 0;
  $firstClick = 1;
  $mineCount->configure(-text => $remainingMines);
  
  # Initialize board cells
  for(my $x = 0; $x < $height; $x++){
    for(my $y = 0; $y < $width; $y++){
      my $cell = Cell->new(); $cell->state(0); $cell->value(0);
      $cell->widget(
        $boardFrame->Button(-background => &buttonBG, -activebackground => &buttonActiveBG,
        -height => 1, -width => 2, -borderwidth => 2, -highlightthickness => 0,
        -command => [\&reveal, $x, $y])->grid(-row => $x, -column => $y, -ipadx => 2,
        -ipady => 2)
      );
      $cell->widget->bind('<3>', [\&toggle_flag, $x, $y]);
      $board[$x][$y] = $cell;
    }
  }
  
  # Initialize mines
  @mineCells = (shuffle 0..($height * $width - 1))[0..$numMines-1];
  foreach my $mine (@mineCells){
    my $x = int($mine / $width);
    my $y = $mine % $width;
    place_mine($x,$y);
  }
}

#-----------------------------------------------------------------------------------------
# Restart Game
#-----------------------------------------------------------------------------------------

sub restart_game {
  # Reset board
  for(my $x = 0; $x < $height; $x++){
    for(my $y = 0; $y < $width; $y++){
      if($board[$x][$y]->state == -1){
        # Hide all revealed cells
        $board[$x][$y]->widget->destroy;
        $board[$x][$y]->widget(
          $boardFrame->Button(
            -background => &buttonBG, -activebackground => &buttonActiveBG,
            -height => 1, -width => 2, -borderwidth => 2, -highlightthickness => 0,
            -command => [\&reveal, $x, $y])->grid(-row => $x, -column => $y, -ipadx => 2,
            -ipady => 2)
        );
        $board[$x][$y]->widget->bind('<3>', [\&toggle_flag, $x, $y]);
        $board[$x][$y]->state(0);
      }elsif($board[$x][$y]->state == 1){
        # Remove any flags on hidden cells
        toggle_flag(0,$x,$y);
      }
    }
  }
  $remainingCells = $height * $width - $numMines;
  $flagsPlaced = 0;
  $remainingMines = $numMines;
  $mineCount->configure(-text => $remainingMines);
}

#-----------------------------------------------------------------------------------------
# Places a mine at the cell (x,y) and increments the mine count of its neighbors
#-----------------------------------------------------------------------------------------

sub place_mine {
  my ($x,$y) = @_;
  $board[$x][$y]->value(-1);
  
  my @neighbors = cell_neighbors($x,$y);
  while(my ($xn,$yn) = splice(@neighbors, 0, 2)){
    unless($board[$xn][$yn]->value == -1){
      $board[$xn][$yn]->value($board[$xn][$yn]->value + 1);
    }
  }
}

#-----------------------------------------------------------------------------------------
# Removes a mine at the cell (x,y) and decrements the mine count of its neighbors
#-----------------------------------------------------------------------------------------

sub remove_mine {
  my ($x,$y) = @_;
  $board[$x][$y]->value(0);
  
  my @neighbors = cell_neighbors($x,$y);
  while(my ($xn,$yn) = splice(@neighbors, 0, 2)){
    if($board[$xn][$yn]->value == -1){
      $board[$x][$y]->value($board[$x][$y]->value + 1);
    }else{
      $board[$xn][$yn]->value($board[$xn][$yn]->value - 1);
    }
  }
}

#-----------------------------------------------------------------------------------------
# Moves the mine at the cell (x,y) to the top left corner or the first available cell to
# the right, excluding those passed in the array at $addr
#-----------------------------------------------------------------------------------------

sub move_mine {
  my ($x,$y,$addr) = @_;
  my @safeCells = @{$addr};
  
  my $mine = $x * $width + $y;
  my $index = 0; $index++ until $mineCells[$index] == $mine;
  $mine = 0;
  while($mine ~~ @mineCells or $mine ~~ @safeCells){ $mine++; }
  $mineCells[$index] = $mine;
  remove_mine($x,$y);
  place_mine(int($mine / $width),$mine % $width);
}

#-----------------------------------------------------------------------------------------
# Returns a list of neighbor (x,y) locations in the form (x1, y1, x2, y2, ...)
#-----------------------------------------------------------------------------------------

sub cell_neighbors {
  my ($x,$y) = @_;
  my @neighbors = ();
  for(my $xn = max(0,$x-1); $xn <= min($x+1,$height-1); $xn++){
    for(my $yn = max(0,$y-1); $yn <= min($y+1,$width-1); $yn++){
      unless($xn == $x and $yn == $y){ push @neighbors, ($xn,$yn); }
    }
  }
  return @neighbors;
}

#-----------------------------------------------------------------------------------------
# Toggles the flag on the selected cell
#-----------------------------------------------------------------------------------------

sub toggle_flag {
  shift;
  my ($x,$y) = @_;
  $board[$x][$y]->state(($board[$x][$y]->state + 1) % 2);
  if( $board[$x][$y]->state ){
    # Place flag
    $board[$x][$y]->widget->configure(
      -image => $img{'flag'}{'photo'}, -height => 17, -width => 16
    );
    $flagsPlaced++;
  }else{
    # Remove flag
    $board[$x][$y]->widget->configure(-image => '', -height => 1, -width => 2);
    $flagsPlaced--;
  }
  
  $remainingMines = $numMines - $flagsPlaced;
  $mineCount->configure(-text => $remainingMines);
}

#-----------------------------------------------------------------------------------------
# Reveals the cell value when a button is clicked
#-----------------------------------------------------------------------------------------

sub reveal {
  my ($x,$y) = @_;
  
  if( $firstClick ){ # Ensure that the first click is an empty cell    
    $firstClick = 0;
    if( $board[$x][$y]->value ){
      # Set cells which cannot hold mines
      my @safeCells = ();
      push @safeCells, sub2ind($x,$y);
      my @neighbors = cell_neighbors($x,$y);
      while(my ($xn,$yn) = splice(@neighbors, 0, 2)){ push @safeCells, sub2ind($xn,$yn); }
      
      # Move all mines in the 3 x 3 grid centered at ($x, $y)
      if( $board[$x][$y]->value < 0 ){ move_mine($x,$y,\@safeCells); }
      @neighbors = cell_neighbors($x,$y);
      while(my ($xn,$yn) = splice(@neighbors, 0, 2)){
        if( $board[$xn][$yn]->value < 0 ){ move_mine($xn,$yn,\@safeCells); }
      }
    }
    reveal($x,$y);
  }elsif( $board[$x][$y]->state == 0 ){
    # Reveal cells which are not flagged or are not already revealed
    if( $board[$x][$y]->value < 0 ){
      explode_mine($x,$y);
      return;
    }else{
      # Convert the button to its underlying label
      $board[$x][$y]->state(-1);
      $board[$x][$y]->widget->destroy;
      $board[$x][$y]->widget(
        $boardFrame->Label(-image => $img{$board[$x][$y]->value}{'photo'},
        -borderwidth => 1, -background => &labelBG)->grid(-row => $x, -column => $y,
        -padx => 1, -pady => 1, -ipadx => 1, -ipady => 1)
      );
      $remainingCells--;
      
      # If the selected cell is a blank cell, cascade reveal
      if( $board[$x][$y]->value == 0 ){
        my @neighbors = cell_neighbors($x,$y);
        while(my ($xn,$yn) = splice(@neighbors, 0, 2)){ reveal($xn,$yn); }
      }
    }
  }
  
  if( !$remainingCells ){ end_game('YOU WIN'); }
}

#-----------------------------------------------------------------------------------------
# Explodes a clicked mine and reveals all other mines on the board, ending the game
#-----------------------------------------------------------------------------------------

sub explode_mine {
  my ($x,$y) = @_;
  
  foreach my $mine (@mineCells){
    my $xm = int($mine / $width);
    my $ym = $mine % $width;
    $board[$xm][$ym]->widget->destroy;
    $board[$xm][$ym]->widget(
      $boardFrame->Label(-image => $img{'mine'}{'photo'}, -borderwidth => 1,
        -background => &labelBG)->grid(-row => $xm, -column => $ym, -padx => 1,
        -pady => 1, -ipadx => 1, -ipady => 1)
    );
    $board[$xm][$ym]->state(-1);
  }
  $board[$x][$y]->widget->configure(-background => &mineBG);
  
  end_game('GAME OVER');
}

#-----------------------------------------------------------------------------------------
# Ends the game and initiates a new game if the player chooses to play again
#-----------------------------------------------------------------------------------------

sub end_game {
  my $txt = shift;
  my $answer = $mainWindow->Dialog(
    -text => $txt, -buttons => ['Restart', 'Play Again','Quit'])->Show(
    -popover => $mainWindow);
  if(not defined $answer or $answer eq 'Play Again'){
    init_game($height, $width, $numMines);
  }elsif($answer eq 'Restart'){
    restart_game();
  }else{ $mainWindow->destroy; }
}

#-----------------------------------------------------------------------------------------
# Util
#-----------------------------------------------------------------------------------------

# Convert subscript indices to linear index
sub sub2ind {
  my ($x,$y) = @_;
  return ($x * $width) + $y;
}