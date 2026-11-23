# Frontend files

This folder contains all the files required to run the frontend.
They are included into the compiler by Frontend.jl, next to them.


## A note on optimization
In order to optimize the code contained here further
it could be efficient to change certain immutable structures to mutable, especially those that change a lot during the frontend passes.

Having investigated this it seems that changing expressions could be a good candidate.
Especially changing how matrices and so on are represented.
Changing those from an immutable list to a vector structure should come with great performance and memory benefits, however, I have not yet managed to get a version of this frontend with such changes working.

This package also make use of the @assign macro from the MetaModelica.jl package.
In some cases for instance when it comes to components these are kept since the result of calling them is a so called deep copy.


If you are reading this an interested in helping out I would prioritize fixing the issues above.
