// SPDX-License-Identifier: MIT
// core_486_config : maps a personality enum to a cpu_features_t record.
//
// Pure combinational helper. Synthesizable. Avoid placing any state here.

module core_486_config
  import core_486_pkg::*;
#(
    parameter cpu_personality_e PERSONALITY = P_386DX_25
) (
    output cpu_features_t features
);

  function automatic cpu_features_t personality_features
      (input cpu_personality_e p);
    cpu_features_t f;
    f.family            = FAM_386;
    f.has_on_die_fpu    = 1'b0;
    f.has_on_die_cache  = 1'b0;
    f.cache_kib_x100    = 16'd0;
    f.clock_mult_x2     = 8'd2;   // 1.0x
    f.base_mhz          = 8'd25;
    f.supports_cr4      = 1'b0;
    f.supports_alignchk = 1'b0;
    unique case (p)
      P_386DX_25: begin
        f.family            = FAM_386;
        f.base_mhz          = 8'd25;
      end
      P_386DX_40: begin
        f.family            = FAM_386;
        f.base_mhz          = 8'd40;
      end
      P_486SX_25: begin
        f.family            = FAM_486;
        f.has_on_die_cache  = 1'b1;
        f.cache_kib_x100    = 16'd800;  // 8.00 KiB
        f.base_mhz          = 8'd25;
        f.supports_cr4      = 1'b1;
        f.supports_alignchk = 1'b1;
      end
      P_486SX_33: begin
        f.family            = FAM_486;
        f.has_on_die_cache  = 1'b1;
        f.cache_kib_x100    = 16'd800;
        f.base_mhz          = 8'd33;
        f.supports_cr4      = 1'b1;
        f.supports_alignchk = 1'b1;
      end
      P_486DX_33: begin
        f.family            = FAM_486;
        f.has_on_die_fpu    = 1'b1;
        f.has_on_die_cache  = 1'b1;
        f.cache_kib_x100    = 16'd800;
        f.base_mhz          = 8'd33;
        f.supports_cr4      = 1'b1;
        f.supports_alignchk = 1'b1;
      end
      P_486DX2_66: begin
        f.family            = FAM_486;
        f.has_on_die_fpu    = 1'b1;
        f.has_on_die_cache  = 1'b1;
        f.cache_kib_x100    = 16'd800;
        f.clock_mult_x2     = 8'd4;     // 2.0x
        f.base_mhz          = 8'd33;
        f.supports_cr4      = 1'b1;
        f.supports_alignchk = 1'b1;
      end
      P_486DX4_100: begin
        f.family            = FAM_486;
        f.has_on_die_fpu    = 1'b1;
        f.has_on_die_cache  = 1'b1;
        f.cache_kib_x100    = 16'd1600; // 16.00 KiB
        f.clock_mult_x2     = 8'd6;     // 3.0x
        f.base_mhz          = 8'd33;
        f.supports_cr4      = 1'b1;
        f.supports_alignchk = 1'b1;
      end
      default: begin
        // Defaults already a safe 386DX-25 profile.
      end
    endcase
    return f;
  endfunction

  assign features = personality_features(PERSONALITY);

endmodule : core_486_config
