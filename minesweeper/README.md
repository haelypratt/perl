# Minesweeper

Minesweeper is a single-player logic game. The rectangular board consists of hidden cells, some of which are mines. The goal of the game is to uncover all non-mine cells without detonating a mine.

## Gameplay

Cells are uncovered by left-clicking the blue cells. Each cell is either blank, a number (1 - 8), or a mine. Blank cells do not neighbor any mine cells. Numbered cells indicate how many of the neighboring eight cells contain a mine and can be used to deduce which cells are mines. Blank cells do not neighbor any mine cells. If a blank cell is revealed, it leads to a cascade, where a large section of the board can potentially be uncovered. Cascades reveal any neighboring blank cells and their neighboring number cells.

Flags can be placed on suspected mine cells or removed by right-clicking a hidden cell. When a flag is placed on a hidden cell, that cell cannot be revealed until the flag is removed.

The number of mines remaining on the board (i.e. the number of mines - number of flagged cells) is displayed at the top of the board and can also be used to determine possible mine configurations.

The game ends when either all non-mine cells are revealed or when a mine is detonated.

## Getting Started

This implementation is built in Perl (v5.12.3 built for MSWin32-x86-multi-thread). To run the game, an equivalent version of Perl must be installed.

### Dependencies

Before running the game, it is necessary to install the Tk module. The **recommended** way to do this is via the Perl Package Manager (PPM). In a terminal window, run the command:

```
ppm install Tk
```

Other ways to install the module are found below. These methods are much slower and much less reliable than via PPM.

**CPAN**

```
cpan App::cpanminus
cpanm Module::Tk
```

**Padre IDE**

Navigate to Run > Run Command. Enter the following command in the dialog box and click 'Ok':

```
cpan Tk
```

### Running the Script

Once the Tk module is installed, the game can be run from the terminal with

```
perl minesweeper.pl
```
