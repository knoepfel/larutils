#!/bin/bash

# pull source code in $WORKSPACE/source
# build in $WORKSPACE/build
# copyback directory is $WORKSPACE/copyBack

# this script is just for building release candidates

usage()
{
  cat 1>&2 <<EOF
Usage: $(basename ${0}) [-h]
       $(basename ${0}) <version> <qual_set> <build_type>

Options:

  -h    This help.

Arguments:

  qual_set         Supported qualifier sets: s8:e7, s11:e7

EOF
}

while getopts :h OPT; do
  case ${OPT} in
    h)
      usage
      exit 1
      ;;
    *)
      usage
      exit 1
  esac
done
shift `expr $OPTIND - 1`
OPTIND=1

working_dir=${WORKSPACE}
version=${LARVER}
qual_set="${QUAL}"
build_type=${BUILDTYPE}
objver=${LAROBJ}

case ${qual_set} in
  s30:e9)
     basequal=e9
     squal=s30
     artver=v1_17_07
     nuver=v1_24_00
     oldver=v05_03_00_rc1
  ;;
  s31:e9)
     basequal=e9
     squal=s31
     artver=v1_18_05
     nuver=v1_25_05
     oldver=v06_00_00_rc2
  ;;
  s33:e10)
     basequal=e10
     squal=s33
     artver=v2_00_02
     nuver=v2_00_00
     oldver=v06_00_00_rc4
  ;;
  s36:e10)
     basequal=e10
     squal=s36
     artver=v2_00_03
     nuver=v2_00_01
     oldver=v06_00_00_rc4
  ;;
  s41:e10)
     basequal=e10
     squal=s41
     artver=v2_03_00
     nuver=v2_04_01
     oldver=v06_06_00
  ;;
  s42:e10)
     basequal=e10
     squal=s42
     artver=v2_04_00
     nuver=v2_04_03
     oldver=v06_08_00
  ;;
  *)
    usage
    exit 1
esac

case ${build_type} in
  debug) ;;
  prof) ;;
  *)
    usage
    exit 1
esac

# check XCode
if [[ `uname -s` == Darwin ]]
then
  OSnum=`uname -r | cut -f1 -d"."`
  xver=`xcodebuild -version | grep Xcode | cut -f2 -d" " | cut -f1 -d"."`
  xcver=`xcodebuild -version | grep Xcode`
  if [[ ${basequal} == e9 ]] && [[ ${xver} < 7 ]] && [[ ${OSnum} > 13 ]]
  then
  echo "${basequal} build not supported on `uname -s`${OSnum} with ${xcver}"
  exit 0
  fi
fi

dotver=`echo ${version} | sed -e 's/_/./g' | sed -e 's/^v//'`

echo "building the larsoft base distribution for ${version} ${dotver} ${qual_set} ${build_type}"

OS=`uname`
if [ "${OS}" = "Linux" ]
then
  id=`lsb_release -is`
  if [ "${id}" = "Ubuntu" ]
  then
    flvr=u`lsb_release -r | sed -e 's/[[:space:]]//g' | cut -f2 -d":" | cut -f1 -d"."`
  else
    flvr=slf`lsb_release -r | sed -e 's/[[:space:]]//g' | cut -f2 -d":" | cut -f1 -d"."`
  fi
elif [ "${OS}" = "Darwin" ]
then
  flvr=d`uname -r | cut -f1 -d"."`
else
  echo "ERROR: unrecognized operating system ${OS}"
  exit 1
fi
echo "build flavor is ${flvr}"
echo ""

qualdir=`echo ${qual_set} | sed -e 's%:%-%'`

set -x

blddir=${working_dir}/build
srcdir=${working_dir}/source
# start with clean directories
rm -rf ${blddir}
rm -rf ${srcdir}
rm -rf $WORKSPACE/copyBack
# now make the dfirectories
mkdir -p ${srcdir} || exit 1
mkdir -p ${blddir} || exit 1
mkdir -p $WORKSPACE/copyBack || exit 1

cd ${blddir} || exit 1
curl --fail --silent --location --insecure -O http://scisoft.fnal.gov/scisoft/bundles/tools/pullProducts || exit 1
chmod +x pullProducts
# source code tarballs MUST be pulled first
./pullProducts ${blddir} source lar_product_stack-${version} || \
      { cat 1>&2 <<EOF
ERROR: pull of lar_product_stack-${version} source failed
EOF
        exit 1
      }
./pullProducts ${blddir} source larbase-${version} || \
      { cat 1>&2 <<EOF
ERROR: pull of larbase-${version} source failed
EOF
        exit 1
      }
./pullProducts ${blddir} source larsoftobj-${objver} || \
      { cat 1>&2 <<EOF
ERROR: pull of larsoftobj-${objver} source failed
EOF
        exit 1
      }
./pullProducts ${blddir} source larsoft-${version} || \
      { cat 1>&2 <<EOF
ERROR: pull of larsoft-${version} failed
EOF
        exit 1
      }
mv ${blddir}/*source* ${srcdir}/

cd ${blddir} || exit 1
echo
echo "begin build"
echo
${WORKSPACE}/artutilscripts/tools/newBuild -t -b ${basequal} ${blddir} ${build_type} lar_product_stack-${version} || \
 { mv ${blddir}/*.log  $WORKSPACE/copyBack/
   exit 1
 }
${WORKSPACE}/artutilscripts/tools/newBuild -t -b ${basequal} -s ${squal} ${blddir} ${build_type} larbase-${version} || \
 { mv ${blddir}/*.log  $WORKSPACE/copyBack/
   exit 1
 }
${WORKSPACE}/artutilscripts/tools/newBuild -t -b ${basequal} ${blddir} ${build_type} larsoftobj-${objver} || \
 { mv ${blddir}/*.log  $WORKSPACE/copyBack/
   exit 1
 }
${WORKSPACE}/artutilscripts/tools/newBuild -t -b ${basequal} -s ${squal} ${blddir} ${build_type} larsoft-${version} || \
 { mv ${blddir}/*.log  $WORKSPACE/copyBack/
   exit 1
 }

echo
echo "move files"
echo
mv ${blddir}/*.bz2  $WORKSPACE/copyBack/
mv ${blddir}/*.txt  $WORKSPACE/copyBack/
rm -rf ${srcdir}
rm -rf ${blddir}

exit 0
