using DataFrames, CSV
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
    char_to_bit(c::Char) = UInt(1 << (Int8(c) - Int8('a')))
    LetterSet(chars) = LetterSet(foldl(|, char_to_bit.(collect(chars)), init=UInt(0)))

    # Set operations. I'm to lazy to figure out how to implement the actual AbstractSet interface.
    Base.intersect(ls1::LetterSet, ls2::LetterSet) = LetterSet(ls1.bits & ls2.bits)
    Base.union(ls1::LetterSet, ls2::LetterSet) = LetterSet(ls1.bits | ls2.bits)
    Base.setdiff(ls1::LetterSet, ls2::LetterSet) = LetterSet(ls1.bits & ~ls2.bits)
    Base.length(ls::LetterSet) = count_ones(ls.bits)
    Base.empty(ls::LetterSet) = ls.bits == 0
    # See? I told you it was just bits.

    # Sorting. Any ol' order will do, but our bits are pretending to be integers
    #   so we'll humor them. Then again, we're all pretending to be something we're not.
    Base.isless(ls1::LetterSet, ls2::LetterSet) = ls1.bits < ls2.bits

    # Visualise. See within. I don't know why I bothered to write this. Seeing is overrated.
    #   But I can't be bothered to delete it, so it's still here. Why are you still here?
    const A_TO_Z = ['a':'z';]
    const A_TO_Z_BITS = char_to_bit.(collect(A_TO_Z))
    to_letters(ls::LetterSet) = A_TO_Z[(A_TO_Z_BITS .& ls.bits) .> 0]
    Base.show(io::IO, ls::LetterSet) = print(io, "LetterSet($(ls.bits); \"$(String(to_letters(ls)))\")")


    ALPHABET_MASK = 0x0000000003ffffff
    find_last_letter(letters::LetterSet) = 64 - leading_zeros(letters.bits)
    find_last_missing(letters::LetterSet) = 64 - leading_zeros(letters.bits ⊻ ALPHABET_MASK)
    fill_last_missing(letters::LetterSet) = LetterSet(letters.bits + (1 << (find_last_missing(letters) - 1)))
end

begin # Anagram, AnagramSet
    # It's an anagram. Not your granama's anagram. Mostly because granama is not a real word.
    # Letters are unique, so a set works fine. That's good, because I wasted a lot of time writing LetterSets
    # We might as well keep the words safe here too, in case we need them later.
    struct Anagram
        letters::LetterSet
        words::Vector{String}
    end
    Base.show(io::IO, a::Anagram) = print(io, "Anagram($(a.letters), $(length(a.words)) words)")
    find_last_letter(anagram::Anagram) = find_last_letter(anagram.letters)

    # An AnagramSet represents multiple anagrams squashed together with:
    #   - `letters` representing the set of used letters. Hopefully that's not a huge surprise.
    #   - `sources` as an array of of smaller AnagramSet and an Anagram that can be squashed
    #       to create this AnagramSet, used to recursively recreate the original Anagrams.
    #       In other words, it's black magic we can use later to turn these stupid things into words.
    #   - Implicit invariant: letters.bits == 0 => sources == [] (i.e. the empty set is foundational)
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
# Maine function.
##########################################################

# Fun fact: Maine produces a large fraction of the worlds Maine lobster. Canada produces the rest.
function Maine()
    @info "Fetching spellbook from the ether"
    raw_words = readlines(download("https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt"))
    @info "Subjecting magic words to mortal combat. Only the strongest survive."
    words5 = unique([lowercase(w) for w in raw_words if length(w) == 5])

    @info "Searching the universe for magic phrases"
    stats = @timed (phrases = find_magic_phrases(words5))

    microparkers = stats.time / (32 * 24 * 60 * 60) * 1_000_000
    @info "Found $(length(phrases)) magic phrases in $microparkers microparkers ($(stats.time)s)"

    CSV.write("janky_phrases.csv", DataFrame(phrases))
    @info "Wrote results to janky_phrases.csv"
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
#   This is the juicy bit and warrents some serious explanation. Too bad.
function find_anagram_sets(anagrams)
    # Put the coolest anagrams first.
    sort!(anagrams, by=x -> x.letters)
    # probably a little faster if this is an array
    anagrams_by_last_letter = group(find_last_letter, anagrams)
    # Everyone likes a rags-to-riches story so we'll start from expactly one nothing.
    current_anagram_sets = [AnagramSet(LetterSet(""))]
    current_anagram_sets_skipped = AnagramSet[AnagramSet(LetterSet("z"))]
    for N in 1:5
        next_anagram_sets_by_letters = DefaultDict{LetterSet, AnagramSet}(AnagramSet, passkey=true)
        next_anagram_sets_by_letters_skipped = DefaultDict{LetterSet, AnagramSet}(AnagramSet, passkey=true)
        for current_set in current_anagram_sets
            missing_letter = find_last_missing(current_set.letters)
            for anagram in anagrams_by_last_letter[missing_letter]
                if no_overlap(current_set, anagram)
                    # try not skiping new last letter
                    union_letters = union(current_set.letters, anagram.letters)
                    union_set = next_anagram_sets_by_letters[union_letters]
                    push!(union_set.sources, current_set => anagram)
                    # try skiping new last letter
                    union_letters_skipped = fill_last_missing(union_letters)
                    union_set_skipped = next_anagram_sets_by_letters_skipped[union_letters_skipped]
                    push!(union_set_skipped.sources, current_set => anagram)
                end
            end
        end
        for current_set_skipped in current_anagram_sets_skipped
            missing_letter = find_last_missing(current_set_skipped.letters)
            for anagram in anagrams_by_last_letter[missing_letter]
                if no_overlap(current_set_skipped, anagram)
                    # we've already skipped a letter, so no choices here
                    union_letters_skipped = union(current_set_skipped.letters, anagram.letters)
                    union_set_skipped = next_anagram_sets_by_letters_skipped[union_letters_skipped]
                    push!(union_set_skipped.sources, current_set_skipped => anagram)
                end
            end
        end
        # Maintain anagram elitism. Coolest AnagramSets go first.
        # eletism should be optional here?
        current_anagram_sets = collect(values(next_anagram_sets_by_letters))
        current_anagram_sets_skipped = collect(values(next_anagram_sets_by_letters_skipped))
        @info "Found $(length(current_anagram_sets)) (no skips) + $(length(current_anagram_sets_skipped)) (with skips) of length $N"
    end
    current_anagram_sets_skipped
end





##########################################################
# Expanding anagram sets into phrases
##########################################################

# Expands the AnagramSets into individual sequences of 5 magic words, recursively.
#   That's a lie. It's a loop, but it sounds cooler if I say it's recursive.
function expand_all(anagram_sets)
    flatten( map(anagram_sets) do anagram_set
        anagram_sequences = expand_anagram_set_to_sequences(anagram_set)
        flatten( map(expand_anagram_sequence, anagram_sequences) )
    end )
end

# The expands an AnagramSet into sequences of Anagrams, by recursively expanding anagram_set.sources.
#   I didn't lie this time. It's actually recursive.
# Each sequence of Anagrams we create represents a unique set of 5 anagrams, ordered by coolness.
#   This ordering is meaningless consequence of poor life choices, don't read into it.
#   A set would be more honest.
# NOTE TO SELF: Probably can be simplified with a SplitApplyCombine function
function expand_anagram_set_to_sequences(anagram_set::AnagramSet)::Vector{Vector{Anagram}}
    if isempty(anagram_set.sources)
        [Anagram[]]
    else
        map(anagram_set.sources) do (subset, anagram)
            map(expand_anagram_set_to_sequences(subset)) do expanded
                vcat(expanded, [anagram])
            end
        end |> flatten # STEAM ROLLER!
    end
end

# Expands a single sequence of anagrams into 1 or more sequences of words matching the anagrams
#   It's really just the cartesian product of each `anagram.words`.
expand_anagram_sequence(seq) = vec(collect(product([anagram.words for anagram in seq]...)))

##########################################################
# Script startup when run directly
##########################################################

if abspath(PROGRAM_FILE) == @__FILE__
    # Fun Fact: If you stretch out Maine's coastline around the equator, people get upset.
    Maine()
end

# Why are you still here? This is the end of the file. That's it.
#   Go read a book or go to the gym or something.
