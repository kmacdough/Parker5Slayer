using Underscores, Test, SplitApplyCombine, DataStructures
using IterTools

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
raw_words = readlines(download("https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt"))
words5 = @_ raw_words |> filter(length(_) == 5, __) .|> lowercase |> unique

anagrams = [Anagram(letters, words) for (letters, words) in pairs(group(LetterSet, words5 )) if length(letters) == 5]

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

@time anagram_sets = find_anagram_sets(anagrams)
# Found 5977 sets of length 5
# Found 640023 sets of length 10
# Found 1272060 sets of length 15
# Found 54626 sets of length 20
# Found 11 sets of length 25
#  12.283061 seconds (13.34 M allocations: 23.023 GiB, 29.51% gc time, 0.69% compilation time)

#Probably has a split-apply-combine functino
function expand_anagram_set(anagram_set::AnagramSet)::Vector{Vector{Anagram}}
    if isempty(anagram_set.sources)
        [Anagram[]]
    else
        map(anagram_set.sources) do (subset, anagram)
            [vcat(expanded, [anagram]) for expanded in expand_anagram_set(subset)]
        end |> flatten
    end
end

# anagram_seqs = expand_anagram_set(anagram_sets[1])

expand_anagram_sequence(seq) = vec(collect(IterTools.product([anagram.words for anagram in seq]...)))
# expand_anagram_sequence(anagram_seqs[1])

function expand_all(anagram_sets)
    all_word_sets = NTuple{5, String}[]
    for anagram_set in anagram_sets
        # println("Expanding set $anagram_set")
        anagram_sequences = expand_anagram_set(anagram_set)
        for anagram_seq in anagram_sequences
            # println("Expanding sequence $anagram_seq")
            word_sets = expand_anagram_sequence(anagram_seq)
            append!(all_word_sets, word_sets)
        end
    end
    all_word_sets
end

expanded = expand_all(anagram_sets)