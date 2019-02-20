__precompile__()
module Awben

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
global const wall = Tile('#', false)
global const floor = Tile(' ', true)


# GLOBAL VARIABLES

global const textwidth = 78
global const width = 22
global const height = 12

# cardinal / all directions
global const cardir = [(1, 0), (-1, 0), (0, 1), (0, -1)]
global const alldir = [x for x=product(-1:1, -1:1) if x ≠ (0, 0)]


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

msg(msgwin, x) = (clear(msgwin); add(msgwin, wrap(x)); refresh(msgwin))
bc(lvl, p) = checkbounds(Bool, lvl, p...)
pass(lvl, p) = bc(lvl, p) && lvl[p...].passable


# MAP

function burrow(lvl, p)
    lvl[p...] = floor
    # repeatedly move in random directions that don't breach existing hallways
    for d = shuffle(cardir)
        if bc(lvl, p.+d) && all(x -> x⋅d == -1 || !pass(lvl, p.+d.+x), alldir)
            burrow(lvl, p.+d)
        end
    end
end

function lvlgen(height, width, pos)
    lvl = fill(wall, height, width)
    burrow(lvl, pos)

    # now try to open up dead ends
    for p = product(axes(lvl)...)
        for d = cardir
            if pass(lvl, p.+d.+d) && all(x -> x⋅d == -1 || !pass(lvl, p.+x), alldir)
                lvl[p.+d...] = floor
            end
        end
    end

    lvl
end

function mapdraw(mapwin, lvl, pos)
    clear(mapwin)
    box(mapwin; bl=ACS_LTEE, br=ACS_BTEE, tr=ACS_TTEE)
    asciimap = map(x -> x.symb^2, lvl)
    asciimap[pos...] = "@ "
    for (idx, line) in enumerate(mapslices(join, asciimap, dims=2))
        add(mapwin, line, idx, 1)
    end
    move(mapwin, pos[1], pos[2]*2-1)
    refresh(mapwin)
end


# STATUS INFO

function statusdraw(statuswin)
    clear(statuswin)
    box(statuswin; tl=ACS_TTEE, bl=ACS_BTEE, br=ACS_RTEE)
    add(statuswin, "you are alive", 1, 1)
    refresh(statuswin)
end


# MAIN CODE

export go
function go()

    pos = [height÷2, width÷2]
    lvl = lvlgen(height, width, pos)

    init()
    refresh()
    mapwin = newwin(height+2, width*2+2, 0, 0)
    statuswin = newwin(height+2, textwidth-width*2 + 1, 0, width*2+1)

    msgborder = newwin(5, textwidth+2, height+1, 0)
    msgwin = subwin(msgborder, 3, textwidth, 1, 1; derived=true)
    box(msgborder)
    refresh(msgborder)

    msg(msgwin, "Welcome to awben!  Type '?' for help.")
    statusdraw(statuswin)
    mapdraw(mapwin, lvl, pos)

    while true
        ch = getch()
        if ch == 'q'
            break
        elseif ch == '?'
            msg(msgwin, "sorry there's actually no help yet")
        end

        # put cursor back onto player
        move(mapwin, pos[1], pos[2]*2-1)
        refresh(mapwin)
    end

    deinit()

end

end
