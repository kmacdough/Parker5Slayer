include("parker_slayer.jl")

@testset begin
    @testset "LetterSet" begin 
        LS = LetterSet
        @test LS("abc") == LS(UInt(7))
        @test LS("abc") == LS(['a', 'b', 'c'])
        @test intersect(LS("abc"), LS("dce")) == LS("c")
        @test union(LS("abc"), LS("dce")) == LS("abcde")
        @test setdiff(LS("abc"), LS("dce")) == LS("ab")
        @test setdiff(LS("abc"), LS("cba")) == LS("")
        @test empty(LS(""))
        @test length("a") == 1
        @test length("five") == 4
        @test LS("abc") < LS("cde")
        @test LS("bc") < LS("aaz")
        @test to_letters(LS("cab")) == collect("abc")
    end

    @testset "no_overlap" begin
        A(chars) = Anagram(LetterSet(chars), [])
        AS(chars) = AnagramSet(LetterSet(chars), [])
        @test no_overlap(A("abc"), A("def"))
        @test no_overlap(A("abc"), AS("def"))
        @test no_overlap(AS("abc"), A("def"))
        @test no_overlap(AS("abc"), AS("def"))
        @test !no_overlap(AS("abc"), AS("cde"))
    end

    @testset "find_magic_phrases" begin
        @test ==(
            find_magic_phrases(["abcde", "efghi", "klmno", "pqrst", "uvwxy"]),
            []
        )
        @test ==(
            find_magic_phrases(["abcde", "fghij", "klmno", "pqrst", "uvwxy"]),
            [("abcde", "fghij", "klmno", "pqrst", "uvwxy")]
        )
        @test ==(
            find_magic_phrases(["abcde", "edcba", "fghij", "klmno", "pqrst", "uvwxy"]),
            [
                ("abcde", "fghij", "klmno", "pqrst", "uvwxy")
                ("edcba", "fghij", "klmno", "pqrst", "uvwxy")
            ]
        )
    end

    @testset "expand_anagram_sequence" begin
        A(words) = Anagram(LetterSet(""), words)
        @test ==(
            Set(expand_anagram_sequence([A(["a"]), A(["b"])])),
            Set([("a", "b")])
        )
        @test ==(
            Set(expand_anagram_sequence([A(["a1", "a2"]), A(["b"])])),
            Set([("a1", "b"), ("a2", "b")])
        )
        @test ==(
            Set(expand_anagram_sequence([A(["a1", "a2"]), A(["b1", "b2"])])),
            Set([("a1", "b1"), ("a1", "b2"), ("a2", "b1"), ("a2", "b2")])
        )
    end
end