import std.stdio;
void main() {
	writeln( gen_z_nums(null) );
}

// for each position i in S, returns the longest prefix of S[i..$]
// that is also a prefix of S
int[] gen_z_nums(in string S) pure @safe
{
	if (S.length == 0) return [];
	else if (S.length == 1) return [0];
	
	int[] Z = new int[S.length];
	Z[0] = 0;
	int start;
	int end;
	
	// speedup on Z[1]
	Z[1] = num_equal_chars(S[1 .. $], S);
	int i = 2;
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

// returns # of chars of beginning of S1 and S2 equal
int num_equal_chars(in string S1, in string S2) pure @safe {
	int i = 0, len = S1.length < S2.length ? S1.length : S2.length;
	while (i < len && S1[i] == S2[i])
		i++;
	return i;
}

unittest {
	assert(num_equal_chars("gef","gef") == 3);
	assert(gen_z_nums("ababaabababb") == [0, 0, 3, 0, 1, 5, 0, 4, 0, 2, 0, 0]);
	assert(gen_z_nums("abcabcdabcabf") == [0, 0, 0, 3, 0, 0, 0, 5, 0, 0, 2, 0, 0]);
	assert(gen_z_nums("aabcaabxaaz") == [0, 1, 0, 0, 3, 1, 0, 0, 2, 1, 0]);
	assert(gen_z_nums("") == []);
	assert(gen_z_nums("a") == [0]);
}