import std.stdio;
import std.range;
import std.traits;
import std.typecons;
import std.conv; //text

void main() {
	writeln("hey");
	
}

/** Match of a single pattern in full to a single text. */
class Match {
	uint Tpos;
	
	this(uint Tpos) { this.Tpos = Tpos; }
	
	override size_t toHash() {
		return to!size_t(Tpos);
	}
	
	override bool opEquals(Object rhs) {
		auto that = cast(Match) rhs;
		return that && this.Tpos == that.Tpos;
	}
	
	override string toString() {
		return text("Match: Text@",Tpos);
	}
}

/** Match of a substring of a pattern to a single text. May specify length of match. */
class SubMatch : Match {
	uint Ppos;
	uint length;
	
	this(uint Tpos, uint Ppos) { 
		this(Tpos, Ppos, 0);
	}
	
	this(uint Tpos, uint Ppos, uint length) {
		super(Tpos);
		this.Ppos = Ppos;
		this.length = length;
	}
	
	override string toString() {
		 return text("Match: Text@",Tpos, "<-> Pattern@",Ppos) ~ (length > 0 ? text(" of length ",length) : "");
		 //return text("Match: Pattern#",Pnum,"@",Ppos," <-> Text#",Tnum,"@",Tpos);//,"of len ",match.length, ":",match);
	}	
}

/** naive matching O(nm)
	Accepts any forward range as the text and pattern whose underlying data are comparable by ==.
	Accepts any function or delegate that takes a Match class and does something with it.
*/
void naiveMatch(T,P,F)(T text, P pattern, F callback) 
if (isForwardRange!T && isForwardRange!P && is(typeof(text.front == pattern.front) == bool) && is(typeof(callback(Match.init)) == void)) 
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
			callback( new Match(posT) );
		text.popFront();
		posT++;
	}
}

unittest {
	Match[] matches;
	auto f = (Match m) { matches ~= m; };
	naiveMatch("abcabc", "bc", f);
	//writeln(typeid(f)); 
	writeln(matches[0].Tpos);
	writeln(matches[0].toHash());
	writeln((new Match(1u)).toHash());
	writeln(matches[0] == new Match(1));
	//assert (matches == [new Match(1), new Match(4)]);
	
	auto m1 = new Match(1), m2 = new Match(1);
	writeln(m1.toHash());
	writeln(m2.toHash());
	writeln(m1 == m2);
	writeln(is(typeof(m1) : Match));
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