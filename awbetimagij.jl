#!/usr/bin/julia

using Base.Iterators
using Random
using LinearAlgebra


# TYPES

struct Tile
    symb::Char
    passable::Bool
end


# GLOBAL VARIABLES

const prompt = ">> "
const textwidth = 80
const width = 10
const height = 10

pos = [height÷2, width÷2]
gamemap = fill(Tile('#', false), height, width)

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

msg = println ∘ wrap
msgln(x) = (msg(x); println())
bc(p) = checkbounds(Bool, gamemap, p...)
pass(p) = bc(p) && gamemap[p...].passable


# GENERATE MAP

function mapgen1(p)
    gamemap[p...] = Tile('.', true)
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
                gamemap[p.+d...] = Tile('.', true)
            end
        end
    end
end

mapgen1([width÷2, height÷2])
mapgen2()


# USER COMMANDS

function help()
    msg("""
        To move around, type a direction (e.g. 'northeast') or abbreviation
        (e.g. 'ne').  Use the 'map' command to view your location.  Type
        'commands' to see a list of all commands.
        """)
end

function commands()
    msgln("""
        You only have to type as many characters as is necessary to identify a
        command.  The characters in brackets are optional.
        """)

    maxlen = maximum(length(name) for (name, _, _)=funcs)

    seen = Set{String}()
    for (name, _, desc) ∈ funcs
        # print as much of command as is necessary to be unambiguous
        bracketidx = 0
        for i ∈ eachindex(name)
            prefix = name[1:i]
            if bracketidx == 0 && prefix ∉ seen && i ≠ length(name)
                bracketidx = i
                print(prefix, "[")
            end
            push!(seen, prefix)
        end

        # if there's some left, print it in brackets
        if bracketidx != 0
            print(name[bracketidx+1:end], "]")
        end

        println(" "^(maxlen - length(name) + 2), desc)
    end
end

function showmap()
    asciimap = map(x -> x.symb^2, gamemap)
    asciimap[pos...] = "@."
    println(join(mapslices(join, asciimap, dims=2), '\n'))
end

function look()
    msg("You see here a '" * gamemap[pos...].symb * "'.")
end

funcs = [
    ("help",     help,     "Shows help on how to play the game."),
    ("commands", commands, "Displays this list of commands."),
    ("map",      showmap,  "Displays a map showing your current location."),
    ("look",     look,     "Examines the map at your current location."),
]


# MAIN CODE

msgln("Welcome to awbetimagij!  Type 'help' for help.\n")

while true
    # read input
    print(prompt)
    input = readline(keep=true)
    if isempty(input); break; end
    input = chomp(input)

    # check for movement first
    found = false
    for (x,i)=[("north", -1), ("south", 1), ("", 0)],
        (y,j)=[("west", -1), ("east", 1), ("", 0)]
        short = (isempty(x) ? "" : x[1]) * (isempty(y) ? "" : y[1])
        if isempty(short); continue; end
        if input == short || input == (x*y)
            found = true
            input = "look"
            pos .+= [i, j]
            if !bc(pos) || !gamemap[pos...].passable
                msg("You can't go that way.")
                pos .-= [i, j]
            end
            break
        end
    end

    # now check for a command
    for (name, func, _) ∈ funcs
        if startswith(name, input)
            found = true
            func()
            break
        end
    end

    if !found
        msg("Unknown command.  Type 'help' for help.")
    end

    println()
end
