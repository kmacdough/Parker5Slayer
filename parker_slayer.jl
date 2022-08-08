using Test, DataFrames, CSV
using DataStructures: DefaultDict
using SplitApplyCombine: group, flatten
using IterTools: product

##########################################################
# Data Structures
##########################################################

begin # LetterSet
    # It's a set of letters. Bits are fast and we like fast so we use bits.
    #   It calls itself it an integer, but don't be fooled. It's just bits, pretending to be an integer.
    #   We can only have 64 things this way, but experts say there aren't that many letters. 
    struct LetterSet
        bits::UInt
    end
    # OOOOH fancy. It works. Trust me. Or don't. I don't really care.
    #   Actually it's good you didn't, because it doesn't really work.
    #   Gold star if you know why. But it's close enough for now.
    char_to_bit(c::Char) = UInt(1 << (Int8(c) - Int8('a')))
    LetterSet(chars) = LetterSet(sum(char_to_bit.(collect(chars))))

    # Set operations. I'm to lazy to figure out how to implement the actual AbstractSet interface.
    Base.intersect(ls1::LetterSet, ls2::LetterSet) = LetterSet(ls1.bits & ls2.bits)
    Base.union(ls1::LetterSet, ls2::LetterSet) = LetterSet(ls1.bits | ls2.bits)
    Base.setdiff(ls1::LetterSet, ls2::LetterSet) = LetterSet(ls1.bits & ~ls2.bits)
    Base.length(ls::LetterSet) = count_ones(ls.bits)
    Base.empty(ls::LetterSet) = ls.bits == 0
    # See? I told you it was just bits.

    # Sorting. Any ol' order will do, but our bits are pretending to be integers
    #   so we'll humor them.
    Base.isless(ls1::LetterSet, ls2::LetterSet) = ls1.bits < ls2.bits

    # Visualise. See within. I don't know why I bothered to write this. Seeing is overrated.
    #   But I can't be bothered to delete it, so it's still here. Why are you still here?
    const A_TO_Z = ['a':'z';]
    const A_TO_Z_BITS = char_to_bit.(collect(A_TO_Z))
    to_letters(ls::LetterSet) = A_TO_Z[(A_TO_Z_BITS .& ls.bits) .> 0]
    Base.show(io::IO, ls::LetterSet) = print(io, "LetterSet($(ls.bits); \"$(String(to_letters(ls)))\")")
end

begin # Anagram, AnagramSet
    # It's an anagram. Not your granama's anagram. Mostly because granama is not a real word,
    #   even though it's kinda looks like grandma.
    # Letters are unique, so a set works fine. That's good, because I wasted a lot of time writing LetterSets
    #   We might as well keep the words safe here too, in case we need them later.
    struct Anagram
        letters::LetterSet
        words::Vector{String}
    end
    Base.show(io::IO, a::Anagram) = print(io, "Anagram($(a.letters), $(length(a.words)) words)")

    # An AnagramSet represents multiple anagrams squashed together with:
    #   - `letters` representing the set of used letters. Hopefully that's not a huge surprise
    #   - `sources` as an array of of smaller AnagramSet and an Anagram that can be squashed
    #       to create this AnagramSet, used to recursively recreate the original Anagrams.
    #       In other words, it's black magic we can use later to turn these stupid things into words.
    #   - Implicit invariant: letters.bits == 0 => sources == [] (i.e. the empty set is fundamental not built)
    #       Invariants are for nerds, though, so you can safely ignore this.
    struct AnagramSet
        letters::LetterSet
        sources::Vector{Pair{AnagramSet, Anagram}}
    end
    AnagramSet(letters::LetterSet) = AnagramSet(letters, [])
    Base.show(io::IO, a::AnagramSet) = print(io, "AnagramSet($(a.letters), $(length(a.sources)) sources)")

    # Takes either Anagrams or AnagramSets or a combination of both and checks for overlapping letters
    no_overlap(a1, a2)::Bool = empty(intersect(a1.letters, a2.letters))
end

##########################################################
# Maine function. Because I'm from Maine. Sorry.
##########################################################

function Maine()
    @info "Grabbing spellbook"
    raw_words = readlines(download("https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt"))
    @info "Selecting suitable magic words"
    words5 = unique([lowercase(w) for w in raw_words if length(w) == 5])

    @info "Searching the universe for magic phrases"
    stats = @timed (phrases = find_magic_phrases(words5))

    milliparkers = stats.time / (32 * 24 * 60 * 60) * 1_000_000
    @info "Found $(length(phrases)) magic phrases in $milliparkers milliparkers ($(stats.time)s)"

    CSV.write("magic_phrases.csv", DataFrame(phrases))
    @info "Wrote results to magic_phrases.csv"
end

function find_magic_phrases(word_list)
    anagrams = [Anagram(letters, words) for (letters, words) in pairs(group(LetterSet, word_list))]
    anagrams = [a for a in anagrams if length(a.letters) == 5]
    anagram_sets = find_anagram_sets(anagrams)
    expand_all(anagram_sets)
end

##########################################################
# Building AnagramSets 
##########################################################

# Finds AnagramSets with a.letters.length == 25.
#   Well, they didn't exist before so I guess we're building them. But that's just philosophical mumbo jumbo.
# `AnagramSet`s are expandable into "sets" of 5 `Anagrams` via
#    - `expand_anagram_set_to_sequences(anagram_set)`
# Assumes:
#  - all(length(a.letters) == 5 for a ∈ angarams)
function find_anagram_sets(anagrams)
    sort!(anagrams, by=x -> x.letters)
    prev_anagram_sets = [AnagramSet(LetterSet(""))]
    for N in 1:5
        anagram_sets_by_letters = DefaultDict{LetterSet, AnagramSet}(AnagramSet, passkey=true)
        a_i = 1
        for prev_set in prev_anagram_sets
            while a_i <= length(anagrams) && anagrams[a_i].letters < prev_set.letters; a_i += 1; end
            for anagram in anagrams[a_i:end]
                if no_overlap(prev_set, anagram)
                    union_set = anagram_sets_by_letters[union(prev_set.letters, anagram.letters)]
                    push!(union_set.sources, prev_set => anagram)
                end
            end
        end
        prev_anagram_sets = sort!(collect(values(anagram_sets_by_letters)), by=x -> x.letters)
        @info "Found $(length(prev_anagram_sets)) sets of length $N"
    end
    prev_anagram_sets
end

##########################################################
# Expanding anagram sets into phrases
##########################################################

# Expands the AnagramSets into individual sequences of 5 words, recursively.
#   That's a lie. It's a loop, but it sounds cooler if I say recursive, doesn't it?
function expand_all(anagram_sets)
    all_word_sets = NTuple{5, String}[]
    for anagram_set in anagram_sets
        @debug "Expanding set $anagram_set"
        anagram_sequences = expand_anagram_set_to_sequences(anagram_set)
        for anagram_seq in anagram_sequences
            @debug "Expanding sequence $anagram_seq"
            word_sets = expand_anagram_sequence(anagram_seq)
            append!(all_word_sets, word_sets)
        end
    end
    all_word_sets
end

# The expands an AnagramSet into sequences of Anagrams, by recursively expanding anagram_set.sources.
#   I didn't lie this time. It's actually recursive.
#   The resulting sequences of Anagrams represent uniqe set of anagrams, arbitrarily ordered by anagram.letters.
#   This ordering is meaningless consequence of poor life choices, don't read into it.
# NOTE TO SELF: Probably can be simplified with a SplitApplyCombine function
function expand_anagram_set_to_sequences(anagram_set::AnagramSet)::Vector{Vector{Anagram}}
    if isempty(anagram_set.sources)
        [Anagram[]]
    else
        map(anagram_set.sources) do (subset, anagram)
            [vcat(expanded, [anagram]) for expanded in expand_anagram_set_to_sequences(subset)]
        end |> flatten
    end
end

# Expands a single sequence of anagrams into 1 or more sequences of words matching the anagrams
#   It's really just the cartesian product of each `anagram.words`.
expand_anagram_sequence(seq) = vec(collect(product([anagram.words for anagram in seq]...)))

##########################################################
# Script startup when run directly
##########################################################

if abspath(PROGRAM_FILE) == @__FILE__
    Maine()
end

# Why are you still here? This is the end of the file. That's it.
#   Go read a book or go to the gym or something.