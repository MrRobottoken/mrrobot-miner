/*
 * MR. ROBOT HASH v1.0  (MRH-256)
 * Project   : $MRRBT - First AMD-Only Solana Mining Kernel
 * Hardware  : AMD Polaris/GCN  (RX 470/480/570/580)
 * Algorithm : Memory-hard SHA-256 with 8MB scratchpad
 *
 * NO NAVIDAD FILTER enforced by host: non-AMD devices are rejected
 * before this kernel is ever loaded.  This kernel is tuned for AMD
 * GCN high memory-bandwidth architecture.
 */

#define MRH_ROUNDS          32u
#define SCRATCHPAD_ENTRIES  262144u   /* 256 K entries × 8 uint32 = 8 MB  */
#define SCRATCHPAD_WORDS    2097152u  /* 2 M uint32 total                  */

/* ----- Bit rotation ---------------------------------------------------- */
#define ROTR(x,n) (((x) >> (n)) | ((x) << (32u - (n))))

/* ----- SHA-256 auxiliary functions ------------------------------------- */
#define Sigma0(x)  (ROTR(x, 2u) ^ ROTR(x,13u) ^ ROTR(x,22u))
#define Sigma1(x)  (ROTR(x, 6u) ^ ROTR(x,11u) ^ ROTR(x,25u))
#define sigma0(x)  (ROTR(x, 7u) ^ ROTR(x,18u) ^ ((x) >>  3u))
#define sigma1(x)  (ROTR(x,17u) ^ ROTR(x,19u) ^ ((x) >> 10u))
#define Ch(x,y,z)  (((x) & (y)) ^ (~(x) & (z)))
#define Maj(x,y,z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))

__constant uint SHA256_K[64] = {
    0x428a2f98u, 0x71374491u, 0xb5c0fbcfu, 0xe9b5dba5u,
    0x3956c25bu, 0x59f111f1u, 0x923f82a4u, 0xab1c5ed5u,
    0xd807aa98u, 0x12835b01u, 0x243185beu, 0x550c7dc3u,
    0x72be5d74u, 0x80deb1feu, 0x9bdc06a7u, 0xc19bf174u,
    0xe49b69c1u, 0xefbe4786u, 0x0fc19dc6u, 0x240ca1ccu,
    0x2de92c6fu, 0x4a7484aau, 0x5cb0a9dcu, 0x76f988dau,
    0x983e5152u, 0xa831c66du, 0xb00327c8u, 0xbf597fc7u,
    0xc6e00bf3u, 0xd5a79147u, 0x06ca6351u, 0x14292967u,
    0x27b70a85u, 0x2e1b2138u, 0x4d2c6dfcu, 0x53380d13u,
    0x650a7354u, 0x766a0abbu, 0x81c2c92eu, 0x92722c85u,
    0xa2bfe8a1u, 0xa81a664bu, 0xc24b8b70u, 0xc76c51a3u,
    0xd192e819u, 0xd6990624u, 0xf40e3585u, 0x106aa070u,
    0x19a4c116u, 0x1e376c08u, 0x2748774cu, 0x34b0bcb5u,
    0x391c0cb3u, 0x4ed8aa4au, 0x5b9cca4fu, 0x682e6ff3u,
    0x748f82eeu, 0x78a5636fu, 0x84c87814u, 0x8cc70208u,
    0x90befffau, 0xa4506cebu, 0xbef9a3f7u, 0xc67178f2u
};

/* SHA-256 IV */
#define IV0 0x6a09e667u
#define IV1 0xbb67ae85u
#define IV2 0x3c6ef372u
#define IV3 0xa54ff53au
#define IV4 0x510e527fu
#define IV5 0x9b05688cu
#define IV6 0x1f83d9abu
#define IV7 0x5be0cd19u

/* ----- SHA-256 single-block compression -------------------------------- */
static void sha256_compress(uint s[8], const uint W_in[16]) {
    uint w[64];
    for (int i = 0; i < 16; i++) w[i] = W_in[i];
    for (int i = 16; i < 64; i++)
        w[i] = sigma1(w[i-2]) + w[i-7] + sigma0(w[i-15]) + w[i-16];

    uint a=s[0], b=s[1], c=s[2], d=s[3];
    uint e=s[4], f=s[5], g=s[6], h=s[7];

    for (int i = 0; i < 64; i++) {
        uint T1 = h + Sigma1(e) + Ch(e,f,g) + SHA256_K[i] + w[i];
        uint T2 = Sigma0(a) + Maj(a,b,c);
        h=g; g=f; f=e; e=d+T1;
        d=c; c=b; b=a; a=T1+T2;
    }
    s[0]+=a; s[1]+=b; s[2]+=c; s[3]+=d;
    s[4]+=e; s[5]+=f; s[6]+=g; s[7]+=h;
}

/* SHA-256 of exactly 64 bytes (32-byte state || 32-byte scratchpad chunk) */
static void sha256_64(const uint inp[16], uint out[8]) {
    uint s[8] = {IV0,IV1,IV2,IV3,IV4,IV5,IV6,IV7};

    /* Block 1 – the 64 bytes of data */
    uint b1[16];
    for (int i = 0; i < 16; i++) b1[i] = inp[i];
    sha256_compress(s, b1);

    /* Block 2 – padding: 0x80  zeros…  len=512 bits (0x200) */
    uint b2[16] = {
        0x80000000u, 0u, 0u, 0u, 0u, 0u, 0u, 0u,
        0u, 0u, 0u, 0u, 0u, 0u,
        0x00000000u, 0x00000200u
    };
    sha256_compress(s, b2);

    for (int i = 0; i < 8; i++) out[i] = s[i];
}

/* SHA-256 of exactly 84 bytes (76-byte block header || 8-byte nonce)    */
/* inp[0..18] = header words, inp[19..20] = nonce hi/lo                 */
static void sha256_84(const uint inp[21], uint out[8]) {
    uint s[8] = {IV0,IV1,IV2,IV3,IV4,IV5,IV6,IV7};

    /* Block 1 – first 64 bytes */
    uint b1[16];
    for (int i = 0; i < 16; i++) b1[i] = inp[i];
    sha256_compress(s, b1);

    /* Block 2 – remaining 20 bytes + padding; length = 84*8 = 672 = 0x2A0 */
    uint b2[16] = {
        inp[16], inp[17], inp[18], inp[19], inp[20],
        0x80000000u,
        0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u,
        0x00000000u, 0x000002A0u
    };
    sha256_compress(s, b2);

    for (int i = 0; i < 8; i++) out[i] = s[i];
}

/* Check leading-zero difficulty (big-endian bit comparison) */
static bool check_difficulty(const uint hash[8], uint bits) {
    uint full_words = bits / 32u;
    uint rem       = bits % 32u;
    for (uint i = 0u; i < full_words && i < 8u; i++)
        if (hash[i] != 0u) return false;
    if (full_words < 8u && rem > 0u) {
        uint mask = 0xFFFFFFFFu << (32u - rem);
        if (hash[full_words] & mask) return false;
    }
    return true;
}

/* =======================================================================
 * KERNEL 1 – mrh_init
 * Generate the 8 MB scratchpad from epoch seed.
 * Each work item produces one 8-word entry:  sha256(epoch || gid)
 * Global size: SCRATCHPAD_ENTRIES  (262144)
 * ======================================================================= */
__kernel void mrh_init(__global uint* scratchpad, uint epoch) {
    uint idx = get_global_id(0);

    /* Single-block SHA-256 of 8 bytes: {epoch, idx}
       Message: 4+4 = 8 bytes → padding: 0x80, zeros, len=0x40 (64 bits) */
    uint blk[16] = {
        epoch, idx,
        0x80000000u, 0u, 0u, 0u, 0u, 0u,
        0u, 0u, 0u, 0u, 0u, 0u,
        0x00000000u, 0x00000040u
    };
    uint s[8] = {IV0,IV1,IV2,IV3,IV4,IV5,IV6,IV7};
    sha256_compress(s, blk);

    uint base = idx * 8u;
    for (uint i = 0u; i < 8u; i++)
        scratchpad[base + i] = s[i];
}

/* =======================================================================
 * KERNEL 2 – mrh_mine
 * Main mining kernel.  Each work item tests one nonce.
 * Global size: batch_size  (e.g. 65536 per call)
 *
 * Algorithm (MRH-256):
 *   1. hash = SHA256(block_header ‖ nonce)            [84 bytes]
 *   2. for r in 0..MRH_ROUNDS:
 *        entry = hash[0] mod SCRATCHPAD_ENTRIES
 *        hash  = SHA256(hash ‖ scratchpad[entry])     [64 bytes]
 *   3. if hash < target → report solution
 * ======================================================================= */
__kernel void mrh_mine(
    __global const uint* scratchpad,   /* 8 MB, read-only                */
    __global const uint* block_header, /* 19 × uint32 = 76 bytes BE      */
    ulong   start_nonce,
    uint    difficulty_bits,
    __global uint*  result_found,      /* output flag:  0=none  1=found  */
    __global ulong* result_nonce,      /* output: winning nonce          */
    __global uint*  result_hash        /* output: 8 × uint32 hash        */
) {
    ulong nonce = start_nonce + (ulong)get_global_id(0);

    /* Build 21-word input: header (words 0..18) + nonce hi/lo (19..20) */
    uint inp[21];
    for (int i = 0; i < 19; i++) inp[i] = block_header[i];
    inp[19] = (uint)(nonce >> 32u);
    inp[20] = (uint)(nonce & 0xFFFFFFFFul);

    /* Step 1: initial SHA-256 */
    uint state[8];
    sha256_84(inp, state);

    /* Step 2: MRH mixing rounds (memory-hard) */
    for (uint r = 0u; r < MRH_ROUNDS; r++) {
        uint entry = state[0] % SCRATCHPAD_ENTRIES;
        uint base  = entry * 8u;

        /* combined = state[0..7] ‖ scratchpad[base..base+7]  (64 bytes) */
        uint combined[16];
        for (int i = 0; i < 8; i++) combined[i]   = state[i];
        for (int i = 0; i < 8; i++) combined[8+i] = scratchpad[base + i];

        sha256_64(combined, state);
    }

    /* Step 3: difficulty check */
    if (check_difficulty(state, difficulty_bits)) {
        uint old = atomic_cmpxchg(result_found, 0u, 1u);
        if (old == 0u) {
            result_nonce[0] = nonce;
            for (int i = 0; i < 8; i++) result_hash[i] = state[i];
        }
    }
}
