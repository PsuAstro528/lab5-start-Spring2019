using Pkg
Pkg.activate(".")
using Glob
if split(pwd(),'/')[end]!="test"
  try 
     cd("test")
  catch
     @error("Could not find test directory from " * pwd() )
  end 
end

using Pkg
if haskey(Pkg.installed(),"NBInclude")
   nbinclude_is_installed = true
   using NBInclude
else
   nbinclude_is_installed = false
   macro nbinclude(name)
         return :( @warn("NBInclude not installed, not parsing " * $name * "."); false )
   end
end

if haskey(Pkg.installed(),"Weave")
   weave_is_installed = true
   using Weave
else
   weave_is_installed = false
   @warn("Weave not installed, not parsing .jmd files.")
end

test_files = glob("test*.jl")
println("# test_files=",test_files)
for fn_test in test_files
    println("# Processing test file ",fn_test,"...")  
    fn_ex_jl = replace(fn_test,r"test(\d)\." => s"../ex\1.")
    fn_ex_jmd = replace(fn_ex_jl,r"\.jl$" => ".jmd")
    fn_ex_nb = replace(fn_ex_jl,r"\.jl$" => ".ipynb")
    if nbinclude_is_installed && isfile(fn_ex_nb)
       println("# Parsing ",fn_ex_nb, "..." )
       @nbinclude(fn_ex_nb)
    elseif weave_is_installed && isfile(fn_ex_jmd)
       println("# Tangling ", fn_ex_jmd, " into ", fn_ex_jl, "..." )
       tangle(fn_ex_jmd)
       include(fn_ex_jl)
    elseif isfile(fn_ex_jl)
       include(fn_ex_jl)
    else
       println("# Can not parse either ", fn_ex_nb, " or ", fn_ex_jmd, " or ", fn_ex_jl )
       false
    end
    println("# Running test file ",fn_test,"...")  
    include(fn_test)
end

