set(CMAKE_CXX_COMPILER "/nix/store/ac1hb5dc2z4biwgy8mjrhlifffkkrvdq-gcc-wrapper-13.2.0/bin/g++")
set(CMAKE_CXX_COMPILER_ARG1 "")
set(CMAKE_CXX_COMPILER_ID "GNU")
set(CMAKE_CXX_COMPILER_VERSION "13.2.0")
set(CMAKE_CXX_COMPILER_VERSION_INTERNAL "")
set(CMAKE_CXX_COMPILER_WRAPPER "")
set(CMAKE_CXX_STANDARD_COMPUTED_DEFAULT "17")
set(CMAKE_CXX_EXTENSIONS_COMPUTED_DEFAULT "ON")
set(CMAKE_CXX_COMPILE_FEATURES "cxx_std_98;cxx_template_template_parameters;cxx_std_11;cxx_alias_templates;cxx_alignas;cxx_alignof;cxx_attributes;cxx_auto_type;cxx_constexpr;cxx_decltype;cxx_decltype_incomplete_return_types;cxx_default_function_template_args;cxx_defaulted_functions;cxx_defaulted_move_initializers;cxx_delegating_constructors;cxx_deleted_functions;cxx_enum_forward_declarations;cxx_explicit_conversions;cxx_extended_friend_declarations;cxx_extern_templates;cxx_final;cxx_func_identifier;cxx_generalized_initializers;cxx_inheriting_constructors;cxx_inline_namespaces;cxx_lambdas;cxx_local_type_template_args;cxx_long_long_type;cxx_noexcept;cxx_nonstatic_member_init;cxx_nullptr;cxx_override;cxx_range_for;cxx_raw_string_literals;cxx_reference_qualified_functions;cxx_right_angle_brackets;cxx_rvalue_references;cxx_sizeof_member;cxx_static_assert;cxx_strong_enums;cxx_thread_local;cxx_trailing_return_types;cxx_unicode_literals;cxx_uniform_initialization;cxx_unrestricted_unions;cxx_user_literals;cxx_variadic_macros;cxx_variadic_templates;cxx_std_14;cxx_aggregate_default_initializers;cxx_attribute_deprecated;cxx_binary_literals;cxx_contextual_conversions;cxx_decltype_auto;cxx_digit_separators;cxx_generic_lambdas;cxx_lambda_init_captures;cxx_relaxed_constexpr;cxx_return_type_deduction;cxx_variable_templates;cxx_std_17;cxx_std_20;cxx_std_23")
set(CMAKE_CXX98_COMPILE_FEATURES "cxx_std_98;cxx_template_template_parameters")
set(CMAKE_CXX11_COMPILE_FEATURES "cxx_std_11;cxx_alias_templates;cxx_alignas;cxx_alignof;cxx_attributes;cxx_auto_type;cxx_constexpr;cxx_decltype;cxx_decltype_incomplete_return_types;cxx_default_function_template_args;cxx_defaulted_functions;cxx_defaulted_move_initializers;cxx_delegating_constructors;cxx_deleted_functions;cxx_enum_forward_declarations;cxx_explicit_conversions;cxx_extended_friend_declarations;cxx_extern_templates;cxx_final;cxx_func_identifier;cxx_generalized_initializers;cxx_inheriting_constructors;cxx_inline_namespaces;cxx_lambdas;cxx_local_type_template_args;cxx_long_long_type;cxx_noexcept;cxx_nonstatic_member_init;cxx_nullptr;cxx_override;cxx_range_for;cxx_raw_string_literals;cxx_reference_qualified_functions;cxx_right_angle_brackets;cxx_rvalue_references;cxx_sizeof_member;cxx_static_assert;cxx_strong_enums;cxx_thread_local;cxx_trailing_return_types;cxx_unicode_literals;cxx_uniform_initialization;cxx_unrestricted_unions;cxx_user_literals;cxx_variadic_macros;cxx_variadic_templates")
set(CMAKE_CXX14_COMPILE_FEATURES "cxx_std_14;cxx_aggregate_default_initializers;cxx_attribute_deprecated;cxx_binary_literals;cxx_contextual_conversions;cxx_decltype_auto;cxx_digit_separators;cxx_generic_lambdas;cxx_lambda_init_captures;cxx_relaxed_constexpr;cxx_return_type_deduction;cxx_variable_templates")
set(CMAKE_CXX17_COMPILE_FEATURES "cxx_std_17")
set(CMAKE_CXX20_COMPILE_FEATURES "cxx_std_20")
set(CMAKE_CXX23_COMPILE_FEATURES "cxx_std_23")

set(CMAKE_CXX_PLATFORM_ID "Linux")
set(CMAKE_CXX_SIMULATE_ID "")
set(CMAKE_CXX_COMPILER_FRONTEND_VARIANT "GNU")
set(CMAKE_CXX_SIMULATE_VERSION "")




set(CMAKE_AR "/nix/store/ac1hb5dc2z4biwgy8mjrhlifffkkrvdq-gcc-wrapper-13.2.0/bin/ar")
set(CMAKE_CXX_COMPILER_AR "/nix/store/a3mmr5jmrd0sjvmnc9vqvs388ppq1bnf-gcc-13.2.0/bin/gcc-ar")
set(CMAKE_RANLIB "/nix/store/ac1hb5dc2z4biwgy8mjrhlifffkkrvdq-gcc-wrapper-13.2.0/bin/ranlib")
set(CMAKE_CXX_COMPILER_RANLIB "/nix/store/a3mmr5jmrd0sjvmnc9vqvs388ppq1bnf-gcc-13.2.0/bin/gcc-ranlib")
set(CMAKE_LINKER "/nix/store/ac1hb5dc2z4biwgy8mjrhlifffkkrvdq-gcc-wrapper-13.2.0/bin/ld")
set(CMAKE_MT "")
set(CMAKE_TAPI "CMAKE_TAPI-NOTFOUND")
set(CMAKE_COMPILER_IS_GNUCXX 1)
set(CMAKE_CXX_COMPILER_LOADED 1)
set(CMAKE_CXX_COMPILER_WORKS TRUE)
set(CMAKE_CXX_ABI_COMPILED TRUE)

set(CMAKE_CXX_COMPILER_ENV_VAR "CXX")

set(CMAKE_CXX_COMPILER_ID_RUN 1)
set(CMAKE_CXX_SOURCE_FILE_EXTENSIONS C;M;c++;cc;cpp;cxx;m;mm;mpp;CPP;ixx;cppm;ccm;cxxm;c++m)
set(CMAKE_CXX_IGNORE_EXTENSIONS inl;h;hpp;HPP;H;o;O;obj;OBJ;def;DEF;rc;RC)

foreach (lang C OBJC OBJCXX)
  if (CMAKE_${lang}_COMPILER_ID_RUN)
    foreach(extension IN LISTS CMAKE_${lang}_SOURCE_FILE_EXTENSIONS)
      list(REMOVE_ITEM CMAKE_CXX_SOURCE_FILE_EXTENSIONS ${extension})
    endforeach()
  endif()
endforeach()

set(CMAKE_CXX_LINKER_PREFERENCE 30)
set(CMAKE_CXX_LINKER_PREFERENCE_PROPAGATES 1)
set(CMAKE_CXX_LINKER_DEPFILE_SUPPORTED TRUE)

# Save compiler ABI information.
set(CMAKE_CXX_SIZEOF_DATA_PTR "8")
set(CMAKE_CXX_COMPILER_ABI "ELF")
set(CMAKE_CXX_BYTE_ORDER "LITTLE_ENDIAN")
set(CMAKE_CXX_LIBRARY_ARCHITECTURE "")

if(CMAKE_CXX_SIZEOF_DATA_PTR)
  set(CMAKE_SIZEOF_VOID_P "${CMAKE_CXX_SIZEOF_DATA_PTR}")
endif()

if(CMAKE_CXX_COMPILER_ABI)
  set(CMAKE_INTERNAL_PLATFORM_ABI "${CMAKE_CXX_COMPILER_ABI}")
endif()

if(CMAKE_CXX_LIBRARY_ARCHITECTURE)
  set(CMAKE_LIBRARY_ARCHITECTURE "")
endif()

set(CMAKE_CXX_CL_SHOWINCLUDES_PREFIX "")
if(CMAKE_CXX_CL_SHOWINCLUDES_PREFIX)
  set(CMAKE_CL_SHOWINCLUDES_PREFIX "${CMAKE_CXX_CL_SHOWINCLUDES_PREFIX}")
endif()





set(CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES "/nix/store/2nhjsfc4pg74vqnsbjmnpi7359y6f3wi-ncurses-6.4-dev/include;/nix/store/sj6sqg8243z11nrlpdgw51p1f39ld63w-curl-8.6.0-dev/include;/nix/store/fbkrax280ivbrr85q8a96fygr6abi610-brotli-1.1.0-dev/include;/nix/store/wb4q4g5fi2q7zdl09x5bmzrc27j4jqzv-libkrb5-1.21.2-dev/include;/nix/store/3xdq5097gx81v0z10yl58rrr3yh33zvx-nghttp2-1.60.0-dev/include;/nix/store/w3lslxp2p1xmgh75jfkl540rns4rshjq-libidn2-2.3.7-dev/include;/nix/store/23wj46rlzy1vda0mkh4n33a1bbs294sm-openssl-3.0.13-dev/include;/nix/store/ii682zz6cn64mrq4w3dfispzhkcv6bhm-libpsl-0.21.5-dev/include;/nix/store/kiz6brcc5m50v4qcmfdhz60qq8pk7vk1-libssh2-1.11.0-dev/include;/nix/store/znghzib6sz0pnpq5b6k2rl3r7wdcjvjw-zlib-1.3.1-dev/include;/nix/store/xsf4db0gvs8fr17c6062877jk6qzhr3n-zstd-1.5.5-dev/include;/nix/store/fa8i4di9wzdjd7cj726j7awlrm2k7skb-jansson-2.14/include;/nix/store/2shkl2914ix0pm0didnjqr689szbwggc-gmp-5.1.3-dev/include;/nix/store/0glhx5lz5iphmz7dqfv5sa903z3adzpv-gnumake-4.4.1/include;/nix/store/a3mmr5jmrd0sjvmnc9vqvs388ppq1bnf-gcc-13.2.0/include/c++/13.2.0;/nix/store/a3mmr5jmrd0sjvmnc9vqvs388ppq1bnf-gcc-13.2.0/include/c++/13.2.0/x86_64-unknown-linux-gnu;/nix/store/a3mmr5jmrd0sjvmnc9vqvs388ppq1bnf-gcc-13.2.0/include/c++/13.2.0/backward;/nix/store/a3mmr5jmrd0sjvmnc9vqvs388ppq1bnf-gcc-13.2.0/lib/gcc/x86_64-unknown-linux-gnu/13.2.0/include;/nix/store/a3mmr5jmrd0sjvmnc9vqvs388ppq1bnf-gcc-13.2.0/include;/nix/store/a3mmr5jmrd0sjvmnc9vqvs388ppq1bnf-gcc-13.2.0/lib/gcc/x86_64-unknown-linux-gnu/13.2.0/include-fixed;/nix/store/gzxqm8dyfirbysqjhh78ivam62ll0m87-glibc-2.39-5-dev/include")
set(CMAKE_CXX_IMPLICIT_LINK_LIBRARIES "stdc++;m;gcc_s;gcc;c;gcc_s;gcc")
set(CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES "/nix/store/zszylfdccccpmqnmzdav3bx7yvlrffg2-ncurses-6.4/lib;/nix/store/s279kslfwqlnx79df9ygj9f758x3skda-brotli-1.1.0-lib/lib;/nix/store/li8plf2qixrlrlny7qhw5ylgq01h3z7q-libkrb5-1.21.2/lib;/nix/store/dvwbmkf5gqwly9ysp6sld4c6iwmqijm3-nghttp2-1.60.0-lib/lib;/nix/store/s32cldbh9pfzd9z82izi12mdlrw0yf8q-libidn2-2.3.7/lib;/nix/store/p25ghy7y53lyc834xnw5mrhfq096wa4x-openssl-3.0.13/lib;/nix/store/kci440kzdmyi7b1axs3w6nlmswk3881j-libpsl-0.21.5/lib;/nix/store/gqrbbhxahk4mayblnc0sfpksgph197bb-libssh2-1.11.0/lib;/nix/store/zph9xw0drmq3rl2ik5slg0n2frw9lw5m-zlib-1.3.1/lib;/nix/store/ss6gh67xv5jw6jh0l7dwmyx9823wvb60-zstd-1.5.5/lib;/nix/store/2v59zbb6i773c1b0mwwdqhw3nghfm6d9-curl-8.6.0/lib;/nix/store/fa8i4di9wzdjd7cj726j7awlrm2k7skb-jansson-2.14/lib;/nix/store/cspwamb7mx5xgi89w7h6fnf2ycq3vfx5-gmp-5.1.3/lib;/nix/store/ddwyrxif62r8n6xclvskjyy6szdhvj60-glibc-2.39-5/lib;/nix/store/a3mmr5jmrd0sjvmnc9vqvs388ppq1bnf-gcc-13.2.0/lib/gcc/x86_64-unknown-linux-gnu/13.2.0;/nix/store/c2yb135iv4maadia5f760b3xhbh6jh61-gcc-13.2.0-lib/lib;/nix/store/ac1hb5dc2z4biwgy8mjrhlifffkkrvdq-gcc-wrapper-13.2.0/bin;/nix/store/a3mmr5jmrd0sjvmnc9vqvs388ppq1bnf-gcc-13.2.0/lib64;/nix/store/a3mmr5jmrd0sjvmnc9vqvs388ppq1bnf-gcc-13.2.0/lib")
set(CMAKE_CXX_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES "")
