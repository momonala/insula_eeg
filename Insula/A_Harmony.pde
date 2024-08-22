class Chord
{
    int root; 
    int third; 
    int fifth; 
    int seventh; 
    int ninth; 
    
    Chord(int _root,
    int _third,
    int _fifth, 
    int _seventh, 
    int _ninth)
    {
        root = _root; 
        third = _third; 
        fifth = _fifth; 
        seventh = _seventh; 
        ninth = _ninth;
    }
}

int C = 0; 
int C_SHARP = 1; 
int D = 2;
int E_FLAT = 3;
int E = 4; 
int F = 5; 
int F_SHARP = 6;
int G = 7;
int A_FLAT = 8;
int A = 9;
int B_FLAT = 10; 
int B = 11; 

/* chromatically linearize: alternate between  */ 

/* lets just use c major as a starting point */ 
Chord one = new Chord(C,E,G,B,D);
Chord two = new Chord(D,F,A,C,E);
Chord three = new Chord(E,G,B,D,E);
Chord four = new Chord(F,A,C,E,G);
Chord five = new Chord(G,B,D,F,A);
Chord six = new Chord(A,C,E,G,B);
Chord seven = new Chord(B,D,F,A,B);
Chord [] natural_chords = { one, two, three, four, five, six, seven };

/* diminished chords */
Chord flat_2 = new Chord(C_SHARP,E,G,B_FLAT,C_SHARP);
Chord flat_3 = new Chord(E_FLAT,F_SHARP,A,C,E_FLAT);
Chord flat_5 = new Chord(F_SHARP,A,C,E_FLAT,F_SHARP);
Chord sharp_5 = new Chord(A_FLAT,B,D,F,A_FLAT);
Chord flat_7 = new Chord(B_FLAT,C_SHARP,E,G, B_FLAT);
Chord [] diminished_chords = { flat_2,flat_3,flat_5,sharp_5,flat_7 };