#!/bin/bash

# build dunepdsprce

PRODUCT_NAME=dunepdsprce

# designed to work on Jenkins
# this is a proof of concept script

# for checking out from JJ's github repo

echo "dunepdsprce JJ github: $JJVERSION"

# -- just the compiler flag, e.g. e14
echo "base qualifiers: $QUAL"

GCCVERS=unknown
if [ $QUAL = e14 ]; then
  GCCVERS=v6_3_0
elif [ $QUAL = e15 ]; then
  GCCVERS=v6_4_0
fi

if [ $GCCVERS = unknown ]; then
  echo "unknown compiler flag: $QUAL"
  exit 1
fi

# -- prof or debug

echo "build type: $BUILDTYPE"

# -- gen, avx, or avx2

echo "simd qualifier: $SIMDQUALIFIER"

echo "workspace: $WORKSPACE"


# Environment setup; look in CVMFS first

if [ -f /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh ]; then
  source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh || exit 1
elif [ -f /grid/fermiapp/products/dune/setup_dune_fermiapp.sh ]; then
  source /grid/fermiapp/products/dune/setup_dune_fermiapp.sh || exit 1
else
  echo "No setup file found."
  exit 1
fi

setup gcc ${GCCVERS}

echo "g++ version query"

g++ -v 2>&1

echo "end g++ version query"

# Use system git on macos, and the one in ups for linux

if ! uname | grep -q Darwin; then
  setup git || exit 1
fi
setup gitflow || exit 1

rm -rf $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/copyBack || exit 1
rm -f $WORKSPACE/copyBack/* || exit 1
cd $WORKSPACE/temp || exit 1
CURDIR=`pwd`

# change all dots to underscores, and capital V's to little v's in the version string

VERSION=`echo ${JJVERSION} | sed -e "s/V/v/g" | sed -e "s/\./_/g"`

LINDAR=linux
FLAVOR=`ups flavor -4`
if [ `uname` = Darwin ]; then
  FLAVOR=`ups flavor -2`
  LINDAR=darwin
fi

touch ${PRODUCT_NAME} || exit 1
rm -rf ${PRODUCT_NAME} || exit 1
touch inputdir || exit 1
rm -rf inputdir || exit 1
mkdir -p ${PRODUCT_NAME}/${VERSION}/source || exit 1
mkdir ${PRODUCT_NAME}/${VERSION}/include || exit 1
mkdir ${PRODUCT_NAME}/${VERSION}/data || exit 1
mkdir ${PRODUCT_NAME}/${VERSION}/ups || exit 1


cat >> ${PRODUCT_NAME}/${VERSION}/ups/${PRODUCT_NAME}.table <<'EOF'
File=Table
Product=dunepdsprce

#*************************************************
# Starting Group definition
Group:

Flavor=ANY
Qualifiers=QUALIFIER_REPLACE_STRING:gen:debug

  Action=DefineFQ
    envSet (DUNEPDSPRCE_FQ_DIR, ${UPS_PROD_DIR}/${UPS_PROD_FLAVOR}-QUALIFIER_REPLACE_STRING-gen-debug)

  Action = ExtraSetup
    setupRequired( gcc ${GCCVERS} )

Flavor=ANY
Qualifiers=QUALIFIER_REPLACE_STRING:avx:debug

  Action=DefineFQ
    envSet (DUNEPDSPRCE_FQ_DIR, ${UPS_PROD_DIR}/${UPS_PROD_FLAVOR}-QUALIFIER_REPLACE_STRING-avx-debug)

  Action = ExtraSetup
    setupRequired( gcc ${GCCVERS} )

Flavor=ANY
Qualifiers=QUALIFIER_REPLACE_STRING:avx2:debug

  Action=DefineFQ
    envSet (DUNEPDSPRCE_FQ_DIR, ${UPS_PROD_DIR}/${UPS_PROD_FLAVOR}-QUALIFIER_REPLACE_STRING-avx2-debug)

  Action = ExtraSetup
    setupRequired( gcc ${GCCVERS} )

Flavor=ANY
Qualifiers=QUALIFIER_REPLACE_STRING:gen:prof

  Action=DefineFQ
    envSet (DUNEPDSPRCE_FQ_DIR, ${UPS_PROD_DIR}/${UPS_PROD_FLAVOR}-QUALIFIER_REPLACE_STRING-gen-prof)

  Action = ExtraSetup
    setupRequired( gcc ${GCCVERS} )

Flavor=ANY
Qualifiers=QUALIFIER_REPLACE_STRING:avx:prof

  Action=DefineFQ
    envSet (DUNEPDSPRCE_FQ_DIR, ${UPS_PROD_DIR}/${UPS_PROD_FLAVOR}-QUALIFIER_REPLACE_STRING-avx-prof)

  Action = ExtraSetup
    setupRequired( gcc ${GCCVERS} )

Flavor=ANY
Qualifiers=QUALIFIER_REPLACE_STRING:avx2:prof


  Action=DefineFQ
    envSet (DUNEPDSPRCE_FQ_DIR, ${UPS_PROD_DIR}/${UPS_PROD_FLAVOR}-QUALIFIER_REPLACE_STRING-avx2-prof)

  Action = ExtraSetup
    setupRequired( gcc ${GCCVERS} )

Common:
   Action=setup
      setupenv()
      proddir()
      ExeActionRequired(DefineFQ)
      envSet(DUNEPDSPRCE_DIR, ${UPS_PROD_DIR})
      envSet(DUNEPDSPRCE_VERSION, ${UPS_PROD_VERSION})
      envSet(DUNEPDSPRCE_INC, ${DUNEPDSPRCE_DIR}/include)
      envSet(DUNEPDSPRCE_LIB, ${DUNEPDSPRCE_FQ_DIR}/lib)
      # add the lib directory to LD_LIBRARY_PATH 
      if ( test `uname` = "Darwin" )
        envPrepend(DYLD_LIBRARY_PATH, ${DUNEPDSPRCE_FQ_DIR}/lib)
      else()
        envPrepend(LD_LIBRARY_PATH, ${DUNEPDSPRCE_FQ_DIR}/lib)
      endif ( test `uname` = "Darwin" )
      # add the bin directory to the path if it exists
      if    ( sh -c 'for dd in bin;do [ -d ${DUNEPDSPRCE_FQ_DIR}/$dd ] && exit;done;exit 1' )
          pathPrepend(PATH, ${DUNEPDSPRCE_FQ_DIR}/bin )
      else ()
          execute( true, NO_UPS_ENV )
      endif ( sh -c 'for dd in bin;do [ -d ${DUNEPDSPRCE_FQ_DIR}/$dd ] && exit;done;exit 1' )
      # useful variables
#      envPrepend(CMAKE_PREFIX_PATH, ${DUNEPDSPRCE_DIR} )  this package doesn't use cmake
#      envPrepend(PKG_CONFIG_PATH, ${DUNEPDSPRCE_DIR} )
      # requirements
      exeActionRequired(ExtraSetup)
End:
# End Group definition
#*************************************************

EOF

# edit in the value of the compiler qualifier.  sed -i has a different syntax on mac and linux so do it this roundabout way

sed -e "s/QUALIFIER_REPLACE_STRING/${QUAL}/g" < ${PRODUCT_NAME}/${VERSION}/ups/${PRODUCT_NAME}.table > ${PRODUCT_NAME}/${VERSION}/ups/${PRODUCT_NAME}.tablenew || exit 1
rm -f ${PRODUCT_NAME}/${VERSION}/ups/${PRODUCT_NAME}.table || exit 1
mv ${PRODUCT_NAME}/${VERSION}/ups/${PRODUCT_NAME}.tablenew ${PRODUCT_NAME}/${VERSION}/ups/${PRODUCT_NAME}.table || exit 1

mkdir inputdir || exit 1
cd inputdir
git clone https://github.com/slaclab/proto-dune-dam-lib.git || exit 1
cd proto-dune-dam-lib || exit 1
git checkout tags/${JJVERSION} || exit 1

# copy all the files that do not need building.  Copy the headers later when we're done as they are in the install directory

cp -R -L dam/source/* ${CURDIR}/${PRODUCT_NAME}/${VERSION}/source || exit 1
cp -R -L data/* ${CURDIR}/${PRODUCT_NAME}/${VERSION}/data || exit 1

DIRNAME=${CURDIR}/${PRODUCT_NAME}/${VERSION}/${FLAVOR}-${QUAL}-${SIMDQUALIFIER}-${BUILDTYPE}
mkdir -p ${DIRNAME} || exit 1
rm -rf ${DIRNAME}/* || exit 1
mkdir ${DIRNAME}/bin || exit 1
mkdir ${DIRNAME}/lib || exit 1

cd ${CURDIR}/inputdir/proto-dune-dam-lib/dam/source/cc/make || exit 1
make clean || exit 1

if [ $BUILDTYPE = prof ]; then
  echo "Making optimized version"
  make PROD=1 target=x86_64-${SIMDQUALIFIER}-${LINDAR} || exit 1
else
  echo "Making debug version"
  make target=x86_64-${SIMDQUALIFIER}-${LINDAR} || exit 1
fi

cp -R -L ${CURDIR}/inputdir/proto-dune-dam-lib/install/x86_64-${SIMDQUALIFIER}-${LINDAR}/bin/* ${CURDIR}/${PRODUCT_NAME}/${VERSION}/${FLAVOR}-${QUAL}-${SIMDQUALIFIER}-${BUILDTYPE}/bin

# JJ builds a program called "reader" which probably shouldn't be in the user's PATH.  Rename it if it exists

if [ -e ${CURDIR}/${PRODUCT_NAME}/${VERSION}/${FLAVOR}-${QUAL}-${SIMDQUALIFIER}-${BUILDTYPE}/bin/reader ]; then
  mv ${CURDIR}/${PRODUCT_NAME}/${VERSION}/${FLAVOR}-${QUAL}-${SIMDQUALIFIER}-${BUILDTYPE}/bin/reader ${CURDIR}/${PRODUCT_NAME}/${VERSION}/${FLAVOR}-${QUAL}-${SIMDQUALIFIER}-${BUILDTYPE}/bin/${PRODUCT_NAME}_testreader
fi

# in the case of the shared libraries, we want to only copy the libraries once, and make new symlinks with relative paths

cd ${CURDIR}/inputdir/proto-dune-dam-lib/dam/export/x86_64-${SIMDQUALIFIER}-${LINDAR}/lib
for LIBFILE in $( ls ); do
	  if [ -h ${LIBFILE} ]; then
	    TMPVAR=`readlink ${LIBFILE}`
	    ln -s `basename ${TMPVAR}` ${CURDIR}/${PRODUCT_NAME}/${VERSION}/${FLAVOR}-${QUAL}-${SIMDQUALIFIER}-${BUILDTYPE}/lib/${LIBFILE} || exit 1
	  else
	    cp ${LIBFILE} ${CURDIR}/${PRODUCT_NAME}/${VERSION}/${FLAVOR}-${QUAL}-${SIMDQUALIFIER}-${BUILDTYPE}/lib || exit 1
	  fi
done

cp -R -L ${CURDIR}/inputdir/proto-dune-dam-lib/install/x86_64-${SIMDQUALIFIER}-${LINDAR}/include/* ${CURDIR}/${PRODUCT_NAME}/${VERSION}/include || exit 1

# assemble the UPS product and declare it

cd ${CURDIR} || exit 1

# for testing the tarball, remove so we keep .upsfiles as is when
# unwinding into a real products area

mkdir .upsfiles || exit 1
cat <<EOF > .upsfiles/dbconfig
FILE = DBCONFIG
AUTHORIZED_NODES = *
VERSION_SUBDIR = 1
PROD_DIR_PREFIX = \${UPS_THIS_DB}
UPD_USERCODE_DIR = \${UPS_THIS_DB}/.updfiles
EOF

ups declare ${PRODUCT_NAME} ${VERSION} -f ${FLAVOR} -m ${PRODUCT_NAME}.table -z `pwd` -r ./${PRODUCT_NAME}/${VERSION} -q ${BUILDTYPE}:${SIMDQUALIFIER}:${QUAL}

rm -rf .upsfiles || exit 1

# clean up
rm -rf ${CURDIR}/inputdir || exit 1

cd ${CURDIR} || exit 1

ls -la

VERSIONDOTS=`echo ${VERSION} | sed -e "s/_/./g"`
SUBDIR=`get-directory-name subdir | sed -e "s/\./-/g"`

# use SUBDIR instead of FLAVOR

FULLNAME=${PRODUCT_NAME}-${VERSIONDOTS}-${SUBDIR}-${SIMDQUALIFIER}-${QUAL}-${BUILDTYPE}

# strip off the first "v" in the version number

FULLNAMESTRIPPED=`echo $FULLNAME | sed -e "s/${PRODUCT_NAME}-v/${PRODUCT_NAME}-/"`

tar -cjf ${FULLNAMESTRIPPED}.tar.bz2 .

# Construct manifest -- need to include gcc and gdb? -- no manifest for this product.

#cat > ${FULLNAME}_MANIFEST.txt <<EOF
#${PRODUCT_NAME}         ${VERSION}         ${FULLNAME}.tar.bz2
#EOF


# Save artifacts.

mv *.bz2  $WORKSPACE/copyBack/ || exit 1
#manifest=${FULLNAME}_MANIFEST.txt
#if [ -f $manifest ]; then
#  mv $manifest  $WORKSPACE/copyBack/ || exit 1
#fi
ls -l $WORKSPACE/copyBack/
cd $WORKSPACE || exit 1
rm -rf $WORKSPACE/temp || exit 1
#dla set +x

exit 0
