#!/usr/bin/julia

using Base.Iterators
using Random
using LinearAlgebra

include("../NCurses.jl/ncurses.jl")
using .NCurses


# TYPES

struct Tile
    symb::Char
    passable::Bool
end
const wall = Tile('#', false)
const floor = Tile(' ', true)


# GLOBAL VARIABLES

const prompt = ">> "
const textwidth = 78
const width = 22
const height = 12

const pos = [height÷2, width÷2]
const gamemap = fill(wall, height, width)

# cardinal / all directions
const cardir = [(1, 0), (-1, 0), (0, 1), (0, -1)]
const alldir = [x for x=product(-1:1, -1:1) if x ≠ (0, 0)]


# HELPER FUNCTIONS

function wrap(str::String)
    words = split(str; keepempty=true)
    first(foldl(words[2:end]; init=(words[1], length(words[1]))) do (s, len), word
        j = length(word)
        if len + j + 1 > textwidth
            (s * "\n" * word, j)
        elseif len == 0
            (s * word, j)
        else
            (s * " " * word, len + j + 1)
        end
    end)
end

msg(x) = (clear(msgwin); add(msgwin, wrap(x)); refresh(msgwin))
bc(p) = checkbounds(Bool, gamemap, p...)
pass(p) = bc(p) && gamemap[p...].passable


# GENERATE MAP

function mapgen1(p)
    gamemap[p...] = floor
    # repeatedly move in random directions that don't breach existing hallways
    for d = shuffle(cardir)
        if bc(p.+d) && all(x -> x⋅d == -1 || !pass(p.+d.+x), alldir)
            mapgen1(p.+d)
        end
    end
end

function mapgen2()
    # now try to open up dead ends
    for p = product(axes(gamemap)...)
        for d = cardir
            if pass(p.+d.+d) && all(x -> x⋅d == -1 || !pass(p.+x), alldir)
                gamemap[p.+d...] = floor
            end
        end
    end
end

function mapdraw()
    clear(mapwin)
    box(mapwin; bl=ACS_LTEE, br=ACS_BTEE, tr=ACS_TTEE)
    asciimap = map(x -> x.symb^2, gamemap)
    asciimap[pos...] = "@ "
    for (idx, line) in enumerate(mapslices(join, asciimap, dims=2))
        add(mapwin, line, idx, 1)
    end
    move(mapwin, pos[1], pos[2]*2-1)
    refresh(mapwin)
end

mapgen1([width÷2, height÷2])
mapgen2()


# STATUS INFO

function statusdraw()
    clear(statuswin)
    box(statuswin; tl=ACS_TTEE, bl=ACS_BTEE, br=ACS_RTEE)
    add(statuswin, "you are alive", 1, 1)
    refresh(statuswin)
end

# MAIN CODE

init()
refresh()
const mapwin = newwin(height+2, width*2+2, 0, 0)
const statuswin = newwin(height+2, textwidth-width*2 + 1, 0, width*2+1)

const msgborder = newwin(5, textwidth+2, height+1, 0)
const msgwin = subwin(msgborder, 3, textwidth, 1, 1; derived=true)
box(msgborder)
refresh(msgborder)

msg("Welcome to awben!  Type '?' for help.")
statusdraw()
mapdraw()

while true
    ch = getch()
    if ch == 'q'
        break
    elseif ch == '?'
        msg("sorry there's actually no help yet")
    end

    # put cursor back onto player
    move(mapwin, pos[1], pos[2]*2-1)
    refresh(mapwin)
end

deinit()
