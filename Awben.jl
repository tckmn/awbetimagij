__precompile__()
module Awben

using Base.Iterators
using Random
using LinearAlgebra

using NCurses


# TYPES

struct Tile
    symb::Char
    passable::Bool
end
global const wall = Tile('#', false)
global const floor = Tile(' ', true)

Level = Array{Tile, 2}
Coord = Tuple{Int, Int}

mutable struct Monster
    symb::Char
    pos::Coord
    hp::Int
end

mutable struct Game
    lvl::Level
    you::Monster
    mons::Array{Monster, 1}
    mapwin::Window
    statuswin::Window
    msgwin::Window
end


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

msg(g::Game, x::String) = (clear(g.msgwin); add(g.msgwin, wrap(x)); refresh(g.msgwin))
bc(lvl::Level, p::Coord) = checkbounds(Bool, lvl, p...)
pass(lvl::Level, p::Coord) = bc(lvl, p) && lvl[p...].passable


# MAP

function burrow(lvl::Level, p::Coord)
    lvl[p...] = floor
    # repeatedly move in random directions that don't breach existing hallways
    for d = shuffle(cardir)
        if bc(lvl, p.+d) && all(x -> x⋅d == -1 || !pass(lvl, p.+d.+x), alldir)
            burrow(lvl, p.+d)
        end
    end
end

function lvlgen(height::Int, width::Int, pos::Coord)
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

function mongen(lvl::Level)
    while true
        p = Tuple(rand(CartesianIndices(lvl)))
        if pass(lvl, p)
            return [Monster('X', p, 10)]
        end
    end
end

function mapdrawmon(g::Game, m::Monster)
    mapredraw(g, m.pos)
    add(g.mapwin, m.symb * g.lvl[m.pos...].symb, m.pos[1], m.pos[2]*2-1)
end

function mapdraw(g::Game)
    clear(g.mapwin)
    box(g.mapwin; bl=ACS_LTEE, br=ACS_BTEE, tr=ACS_TTEE)
    asciimap = map(x -> x.symb^2, g.lvl)
    for (idx, line) in enumerate(mapslices(join, asciimap, dims=2))
        add(g.mapwin, line, idx, 1)
    end
    mapdrawmon.((g,), g.mons)
    mapdrawmon(g, g.you)
    move(g.mapwin, g.you.pos[1], g.you.pos[2]*2-1)
    refresh(g.mapwin)
end

function mapredraw(g::Game, p::Coord)
    add(g.mapwin, g.lvl[p...].symb^2, p[1], p[2]*2-1)
end


# STATUS INFO

function statusdraw(g::Game)
    clear(g.statuswin)
    box(g.statuswin; tl=ACS_TTEE, bl=ACS_BTEE, br=ACS_RTEE)
    add(g.statuswin, "you have $(g.you.hp) hp", 1, 1)
    refresh(g.statuswin)
end


# MAIN CODE

function monat(g::Game, p::Coord)::Union{Monster, Nothing}
    for mon in g.mons
        if mon.pos == p
            return mon
        end
    end
end

function trymove(g::Game, d::Coord)
    newpos = g.you.pos .+ d
    if pass(g.lvl, newpos) && isnothing(monat(g, newpos))
        g.you.pos = newpos
        mapdrawmon(g, g.you)
        mapredraw(g, g.you.pos .- d)
        refresh(g.mapwin)
    else
        msg(g, "You can't go that way.")
    end
end

export go
function go()

    init()
    refresh()

    mapwin = newwin(height+2, width*2+2, 0, 0)
    statuswin = newwin(height+2, textwidth-width*2 + 1, 0, width*2+1)

    msgborder = newwin(5, textwidth+2, height+1, 0)
    msgwin = subwin(msgborder, 3, textwidth, 1, 1; derived=true)
    box(msgborder)
    refresh(msgborder)

    pos = (height÷2, width÷2)
    lvl = lvlgen(height, width, pos)
    mons = mongen(lvl)
    g = Game(lvl, Monster('@', pos, 100), mons, mapwin, statuswin, msgwin)

    msg(g, "Welcome to awben!  Type '?' for help.")
    statusdraw(g)
    mapdraw(g)

    while true
        ch = getch()
        msg(g, "")
        if ch == 'q'; break
        elseif ch == 'h'; trymove(g, ( 0, -1))
        elseif ch == 'j'; trymove(g, ( 1,  0))
        elseif ch == 'k'; trymove(g, (-1,  0))
        elseif ch == 'l'; trymove(g, ( 0,  1))
        elseif ch == '?'
            msg(g, "But nobody came.")
        end

        # put cursor back onto player
        move(mapwin, g.you.pos[1], g.you.pos[2]*2-1)
        refresh(mapwin)
    end

    deinit()

end

end
