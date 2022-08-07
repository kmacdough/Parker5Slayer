using Test, DataFrames, CSV
using DataStructures: DefaultDict
using SplitApplyCombine: group, flatten
using IterTools: product

begin # struct LetterSet
    char_to_bit(c::Char) = 1 << (Int8(c) - Int8('a'))
    # could we make this officially look like a set?
    struct LetterSet
        bits::Int
    end
    LetterSet(chars) = LetterSet(sum(char_to_bit.(collect(chars))))

    # Set-like operations
    Base.intersect(ls1::LetterSet, ls2::LetterSet) = LetterSet(ls1.bits & ls2.bits)
    Base.union(ls1::LetterSet, ls2::LetterSet) = LetterSet(ls1.bits | ls2.bits)
    Base.setdiff(ls1::LetterSet, ls2::LetterSet) = LetterSet(ls1.bits & ~ls2.bits)
    Base.length(ls::LetterSet) = count_ones(ls.bits)
    Base.empty(ls::LetterSet) = ls.bits == 0

    # Sorting
    Base.isless(ls1::LetterSet, ls2::LetterSet) = ls1.bits < ls2.bits

    # Visualising
    A_TO_Z = ['a':'z';]
    A_TO_Z_BITS = char_to_bit.(collect(A_TO_Z))
    to_letters(ls::LetterSet) = A_TO_Z[(A_TO_Z_BITS .& ls.bits) .> 0]
    Base.show(io::IO, ls::LetterSet) = print(io, "LetterSet($(ls.bits); \"$(String(to_letters(ls)))\")")

    if false # Inline tests
        @testset "LetterSet" begin 
            LS = LetterSet
            @test LS("abc") == LS(7)
            @test LetterSet("abc") == LetterSet(['a', 'b', 'c'])
            @test union(LS("abc"), LS("dce")) == LS("abcde")
            @test intersect(LS("abc"), LS("dce")) == LS("c")
            @test setdiff(LS("abc"), LS("dce")) == LS("ab")
            @test setdiff(LS("abc"), LS("cba")) == LS("")
            @test empty(LS(""))
            @test length("a") == 1
            @test length("five") == 4
            @test to_letters(LetterSet("cab")) == collect("abc")
        end
    end
end

begin # structs Anagram, AnagramSet
    struct Anagram
        letters::LetterSet
        words::Vector{String}
    end
    Base.show(io::IO, a::Anagram) = print(io, "Anagram($(a.letters), $(length(a.words)) words)")

    struct AnagramSet
        # letters used by this anagram set
        letters::LetterSet
        # ways to build this AnagramSet from one Anagram and a smaller AnagramSet
        sources::Vector{Pair{AnagramSet, Anagram}}
    end
    AnagramSet(letters::LetterSet) = AnagramSet(letters, [])
    Base.show(io::IO, a::AnagramSet) = print(io, "AnagramSet($(a.letters), $(length(a.sources)) sources)")

    no_overlap(a1, a2) = empty(intersect(a1.letters, a2.letters))
end

# raw_words = readlines("/usr/share/dict/words")

function main()
    println("Grabbing spellbook")
    raw_words = readlines(download("https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt"))
    println("Selecting suitable magic words")
    words5 = unique([lowercase(w) for w in raw_words if length(w) == 5])

    println("Searching the universe for magic phrases")
    stats = @timed (phrases = find_magic_phrases(words5))

    milliparkers = stats.time / (32 * 24 * 60 * 60) * 1_000_000
    println("Found $(length(phrases)) magic phrases in $milliparkers milliparkers ($(stats.time)s)")

    CSV.write("word_sets.csv", DataFrame(phrases))
    println("Wrote results to word_sets.csv")
end

function find_magic_phrases(word_list)
    anagrams = [Anagram(letters, words) for (letters, words) in pairs(group(LetterSet, word_list))]
    anagrams = [a for a in anagrams if length(a.letters) == 5]
    anagram_sets = find_anagram_sets(anagrams)
    expanded = expand_all(anagram_sets)
end

function find_anagram_sets(anagrams)
    sort!(anagrams, by=x -> x.letters)
    prev_anagram_sets = [AnagramSet(LetterSet(0))]
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
        println("Found $(length(prev_anagram_sets)) sets of length $(length(prev_anagram_sets[1].letters))")
    end
    prev_anagram_sets
end

function expand_all(anagram_sets)
    all_word_sets = NTuple{5, String}[]
    for anagram_set in anagram_sets
        # println("Expanding set $anagram_set")
        anagram_sequences = expand_anagram_set_to_sequences(anagram_set)
        for anagram_seq in anagram_sequences
            # println("Expanding sequence $anagram_seq")
            word_sets = expand_anagram_sequence(anagram_seq)
            append!(all_word_sets, word_sets)
        end
    end
    all_word_sets
end

#Probably has a split-apply-combine functino
function expand_anagram_set_to_sequences(anagram_set::AnagramSet)::Vector{Vector{Anagram}}
    if isempty(anagram_set.sources)
        [Anagram[]]
    else
        map(anagram_set.sources) do (subset, anagram)
            [vcat(expanded, [anagram]) for expanded in expand_anagram_set_to_sequences(subset)]
        end |> flatten
    end
end

expand_anagram_sequence(seq) = vec(collect(product([anagram.words for anagram in seq]...)))

main()