# Modelica Standard Libraries

This folder contains some versions of the Modelica Standard Library(MSL)

## On use and extension
Currently, until a more solid option is implemented versions of the MSL should be added to this folder
with the name `MSL_X_Y_Z.mo` where X,Y and Z are numbers indicating the version of the library.

## License
See the libraries themselves for the applicable license.

## Regenerating a bundle
`loadMSL.mos` writes the bundle with omc (`loadModel`, then `writeFile(..., list())`). Check the result against the
library's sources: omc 1.27.1 prints an element-wise operator after an integer literal without a space (`1 ./ x`
as `1./x`), and `1./x` reads back as `1.0 / x`, a scalar divided by an array. `grep -rnE '[0-9] +\.[*/^]'` over the
library's `.mo` files lists them; restore the space in the bundle (MSL 4.1.0: `Media.Incompressible`'s `invTK`, two
operators).
