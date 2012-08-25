/// Authors: Dylan Hutchison

import std.stdio;
import std.range;
import std.traits;
import std.typecons;
import std.conv; //text

void main() {
	auto text = "barry goldwater hunted for gold beneath a golden sunset";
	string[uint] aa;
	naiveMatch!((Match m) { aa[m.Tpos] = text[m.Tpos .. $]; return false; })(text, "gold");
	writeln(aa);
	
}

/** Match of a single pattern in full to a single text. */
struct Match {
	uint Tpos ;
	
	this(uint Tpos) { this.Tpos = Tpos; }
	
	string toString() {
		return text("Match: Text@",Tpos);
	}
	
	/**	Function that calls a stringfun and puts all the matches generated into an array, and then returns the entire array once finished.
	
	*/
	static Match[] getAllMatches(alias stringfun, A...)(A args) 
	//if (is(typeof(stringfun!(function bool(Match m) {return false;}, A) (args)) == void))
	// COMPILER BUG ^ The above line should work, but it breaks the compiler...
	// Assertion failure: 'fd && fd->inferRetType' on line 81 in file 'mangle.c'
	// look here: http://d.puremagic.com/issues/show_bug.cgi?id=8499
	// The point of doing all this is to make the unittests look nicer...
	in {
		// this will have to suffice
		static if (!is(typeof(stringfun!(function bool(Match m) {return false;}, A) (args)) == void))
			assert(false, "bad argument to getAllMatches");
	}
	body {
		
		/*foreach(a; args)
			writeln(a);
		foreach(a; A)
			writeln(typeid(a));
		writeln(typeid(stringfun!((Match m) {return false;}, A) (args)) );
		*/
		Match[] mall;
		stringfun!((Match m) { mall ~= m; return false; }, A)(args);
		return mall;
	}
}

/** Match of a substring of a pattern to a single text. May specify length of match. */
struct SubMatch {
	private Match _match; 
	alias _match this;		// SubMatch is a subtype of Match
	
	uint Ppos = 0;
	uint length = 0;
	
	this(uint Tpos, uint Ppos) { 
		this(Tpos, Ppos, 0);
	}
	
	this(uint Tpos, uint Ppos, uint length) {
		_match = Match(Tpos);
		this.Ppos = Ppos;
		this.length = length;
	}
	
	string toString() {
		 return text("Match: Text@",Tpos, "<-> Pattern@",Ppos) ~ (length > 0 ? text(" of length ",length) : "");
		 //return text("Match: Pattern#",Pnum,"@",Ppos," <-> Text#",Tnum,"@",Tpos);//,"of len ",match.length, ":",match);
	}	
}


/** naive matching O(nm)
	Accepts any forward range as the text and pattern whose underlying data are comparable by ==.
	Accepts any function or delegate that takes a Match class and does something with it; STOPS the search if the function returns true.
*/
void naiveMatch(alias callback,T,P)(T text, P pattern) 
if (isForwardRange!T && isForwardRange!P && is(typeof(text.front == pattern.front) == bool) && is(typeof(callback(Match.init)) == bool)) 
{
	T textCompStart = text.save();
	P patternFront = pattern.save();
	auto posT = 0;
	while (!text.empty) {
		T textComp = text.save();
		P patternComp = pattern.save();
		auto posTcomp = posT, posPcomp = 0;
		while (!textComp.empty && !patternComp.empty && textComp.front == patternComp.front) {
			textComp.popFront();
			patternComp.popFront();
			posTcomp++; posPcomp++;
		}
		if (patternComp.empty)
			if (callback( Match(posT) ))
				return;
		text.popFront();
		posT++;
	}
}

// A lot of these tests are an attempt to have fun with compile-time execution ^.^
unittest {
	static Match[] matches;
	auto f = (Match m) { matches ~= m; return false; };
	naiveMatch!f("abcabc", "bc");
	assert(matches == [Match(1), Match(4)]);
	
	matches = [];
	naiveMatch!f("abcabc","");
	static Match[] allMatch;
	foreach(i; 0 .. "abcabc".length)
		allMatch ~= Match(i);
	assert(matches == allMatch);
	
	
	static mats = Match.getAllMatches!naiveMatch("abcabc", "bc");
	writeln("mats is ",mats);
	assert(mats == [Match(1), Match(4)]);
	
	static assert(Match.getAllMatches!naiveMatch("abcabc", "a") == [Match(0), Match(3)]);
	static assert(Match.getAllMatches!naiveMatch("", "a") == []);
	static assert(Match.getAllMatches!naiveMatch("", "") == []);
		
	enum mas = () {
			Match[] mm;
			naiveMatch!((Match m) { mm ~= m; return false; })("abcabc", "bc");
			return mm;
		}();
	static assert(mas == [Match(1), Match(4)]);
	
	// test the ability to stop prematurely
	enum mas2 = () {
			Match[] mm;
			naiveMatch!((Match m) { mm ~= m; return m.Tpos == 1u; })("abcabc", "bc");
			return mm;
		}();
	static assert(mas2 == [Match(1)]);
}



// simple linear exact matching O(n+m)

// returns # of chars of beginning of S1 and S2 equal
uint num_equal_chars(in string S1, in string S2) pure @safe nothrow {
	auto i = 0u, len = S1.length < S2.length ? S1.length : S2.length;
	while (i < len && S1[i] == S2[i])
		i++;
	return i;
}

// for each position i in S past the first, returns the longest prefix of S[i..$]
// that is also a prefix of S
uint[] gen_z_nums(in string S) pure @safe nothrow
{
	if (S.length == 0) return [];
	else if (S.length == 1) return [0u];
	
	uint[] Z = new uint[S.length];
	Z[0] = 0;
	uint start;
	uint end;
	
	// speedup on Z[1]
	Z[1] = num_equal_chars(S[1 .. $], S);
	auto i = 2u;
	for ( ; i < Z.length && Z[i-1] > 0; i++)
		Z[i] = Z[i-1]-1;
	// i is after the first different character
	
	start = end = i;
	for ( ; i < Z.length; i++) {
		if (i >= end) {
			// outside a Z box
			Z[i] = num_equal_chars(S[i .. $], S);
			start = i;
			end = i + Z[i];
		} else {
			// in a Z box because i < end
			auto numleft = end - i;
			auto corr_pos = i - start;
			if (Z[corr_pos] < numleft)
				Z[i] = Z[corr_pos];
			else if (Z[corr_pos] > numleft)
				Z[i] = numleft;
			else {
				// they're equal - try to extend beyond Z box
				Z[i] = numleft + num_equal_chars(S[end .. $], S[numleft .. $]);
				start = i;
				end = i + Z[i];
			}
		}
	}
	return Z;
}

/*
// for each position i in S past the first, returns the longest prefix of S[i..$]
// that is also a prefix of S.  ONLY RETURNS NON-ZERO ENTRIES (assoc. / sparse array)
uint[uint] gen_z_nums_sparse(in string S)
{
	if (S.length == 0) return null;
	else if (S.length == 1) return [0u:0u];
	
	void addIfNotDefault(K,V)(ref V[K] AA, in K key, in V val, in V def) pure @safe nothrow {
		if (val != def)
		 AA[key] = val;
	}
	
	uint[uint] Z;
	//Z[0] = 0;
	uint start;
	uint end;
	uint i = 2u;
	
	// speedup on Z[1]
	{
		auto tmp = num_equal_chars(S[1 .. $], S);
		while (tmp > 0 && i < S.length)
			Z[i++] = tmp--;
		i++;
	}
	// i is after the first different character
	
	start = end = i;
	for ( ; i < S.length; i++) {
		
		if (i >= end) {
			// outside a Z box
			addIfNotDefault!(uint,uint)(Z, i, num_equal_chars(S[i .. $], S), 0u);
			start = i;
			end = i + Z.get(i, 0u);
		} else {
			// in a Z box because i < end
			auto numleft = end - i;
			auto corr_pos = i - start;
			if (Z.get(corr_pos,0u) < numleft)
				Z[i] = Z.get(corr_pos,0u);
			else if (Z.get(corr_pos,0u) > numleft)
				Z[i] = numleft;
			else {
				// they're equal - try to extend beyond Z box
				Z[i] = numleft + num_equal_chars(S[end .. $], S[numleft .. $]);
				start = i;
				end = i + Z[i];
			}
		}
		writefln("%d: %d %s", i, num_equal_chars(S[i .. $], S), Z);
	}
	return Z;
}*/

/* Knuth-Morris-Pratt exact string matching O(n+m)
	streaming algorithm - can accept the text in real time as only one comparison per
	text character is needed
   Returns an array of the positions of the exact matches in the text.
/
uint[] kmp_exact_streaming_match(in string P, in string T) pure @safe nothrow {
	uint[uint][char] st; // shift table -- if char x in T mismatches at i, shift Tpos by st[x][i]
	
	// ****** innitialize the st to all full shifts ******
	// first get all the unique characters
	foreach (i, c; P) {
		//if (c in st)
			
		
		
	}
		
	
	
	uint[] Z = gen_z_nums(P);
	
	
	
	return [];
} */
 




unittest {
	assert(num_equal_chars("gef","gef") == 3u);
	assert(gen_z_nums("ababaabababb") == [0, 0, 3, 0, 1, 5, 0, 4, 0, 2, 0, 0]);
	assert(gen_z_nums("abcabcdabcabf") == [0, 0, 0, 3, 0, 0, 0, 5, 0, 0, 2, 0, 0]);
	assert(gen_z_nums("aabcaabxaaz") == [0, 1, 0, 0, 3, 1, 0, 0, 2, 1, 0]);
	assert(gen_z_nums("") == [] && gen_z_nums(null) == []);
	assert(gen_z_nums("a") == [0]);
	assert(gen_z_nums("aaaaaaa") == [0, 6, 5, 4, 3, 2, 1]);
}