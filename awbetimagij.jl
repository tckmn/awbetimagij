#!/usr/bin/julia


# TYPES

mutable struct Tile
    symb::Char
end


# GLOBAL VARIABLES

prompt = ">> "
textwidth = 80
width = 40
height = 12
pos = [height÷2, width÷2]
gamemap = [Tile('.') for _=1:height, _=1:width]
gamemap[5,18].symb = 'X'


# HELPER FUNCTIONS

function wrap(str::String)
    words = split(str; keepempty=true)
    foldl(((s, len), word) ->
        len + 1 + (j = length(word)) > textwidth ?
            (s * "\n" * word, j) :
            len == 0 ? (s * word, j) : (s * " " * word, len + 1 + j),
        words[2:end]; init=(words[1], length(words[1])))[1]
end

msg = println ∘ wrap


# USER COMMANDS

function help()
    msg("""
        To move around, type a direction (e.g. 'northeast') or abbreviation
        (e.g. 'ne').  Use the 'map' command to view your location.  Type
        'commands' to see a list of all commands.
        """)
end

function commands()
    msg("""
        You only have to type as many characters as is necessary to identify a
        command.  The characters in brackets are optional.
        """)
    println()

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

        println(repeat(" ", maxlen - length(name) + 2), desc)
    end
end

function showmap()
    asciimap = map(x -> x.symb, gamemap)
    asciimap[pos...] = '@'
    println(join(mapslices(join, asciimap, dims=2), '\n'))
end

funcs = [
    ("help",     help,     "Shows help on how to play the game."),
    ("commands", commands, "Displays this list of commands."),
    ("map",      showmap,  "Displays a map showing your current location."),
]


# MAIN CODE

println("Welcome to awbetimagij!  Type 'help' for help.\n")

while true
    # read input
    print(prompt)
    input = readline(keep=true)
    if isempty(input)
        break
    end
    input = input[1:end-1]  # discard newline

    # check for movement first
    found = false
    for (x,i)=[("north", -1), ("south", 1), ("", 0)],
        (y,j)=[("west", -1), ("east", 1), ("", 0)]
        short = (isempty(x) ? "" : x[1]) * (isempty(y) ? "" : y[1])
        if isempty(short)
            continue
        end
        if input == short || input == (x*y)
            found = true
            pos .+= [i, j]
            if checkbounds(Bool, gamemap, pos...)
                println("You see here a '", gamemap[pos...].symb, "'.")
            else
                println("You can't go that way.")
                pos .-= [i, j]
            end
            break
        end
    end

    # now check for a command
    if !found
        for (name, func, _) ∈ funcs
            if startswith(name, input)
                found = true
                func()
                break
            end
        end
    end

    if !found
        println("Unknown command.  Type 'help' for help.")
    end

    println()
end
