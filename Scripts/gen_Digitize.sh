#!/usr/bin/bash
#
# generate fcl for digitizing simulated primary particles without pileup background
# this script requires mu2etools, mu2efiletools and dhtools be setup
# It also requires the SimEfficiencies for the beam campaign be entered in the database
#
usage() { echo "Usage: $0 [ --primary primary physics process name ]
  [ --campaign campaign name e.g. MDC2020 ]
  [ --pver primary campaign version e.g 'p']
  [ --over output campaign version e.g. 'v' ]
  [ --digitype  digitization type e.g. OnSpill, OffSpill, NoField, Extracted]
  [ --dbpurpose purpose of db e.g. perfect, startup, best  ]
  [ --dbversion db version ]
  [ --merge (opt) merge factor, default 10 ]
  [ --owner (opt) default mu2e ]
  [ --samopt (opt) Options to samListLocation default "-f --schema=root" ]
  [ --field (opt) default = DS +TSD, override for special runs ]
  e.g.  Production/Scripts/gen_Digitize.sh --primary CeEndpoint --campaign MDC2020 --pver t --over t --digitype OnSpill --dbpurpose perfect --dbversion v1_0"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}

# required configuration parameters
PRIMARY=""
CAMPAIGN=""
PRIMARY_VERSION=""
OUTPUT_VERSION=""
DIGITYPE=""
DBPURPOSE=""
DBVERSION=""
# The following options can be overridden if needed
MERGE="10"
OWNER=mu2e
SAMOPT="-f --schema=root"
FIELD="Offline/Mu2eG4/geom/bfgeom_no_tsu_ps_v01.txt" #optional (for changing field map)
OUTDESC=""

# Loop: Get the next option;
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        campaign)
          CAMPAIGN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        primary)
          PRIMARY=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        pver)
          PRIMARY_VERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        over)
          OUTPUT_VERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        merge)
          MERGE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        digitype)
          DIGITYPE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        dbpurpose)
          DBPURPOSE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        dbversion)
          DBVERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        owner)
          OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        samopt)
          SAMOPT=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        field)
          FIELD=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        desc)
          OUTDESC=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        esac;;
    :)                                    # If expected argument omitted:
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal                       # Exit abnormally.
      ;;
    *)                                    # If unknown (any other) option:
      echo "Unknown option ${OPTARG}"
      exit_abnormal                       # Exit abnormally.
      ;;
    esac
done

# basic tests
if [[ ${CAMPAIGN} == ""  || ${PRIMARY} == "" || ${PRIMARY_VERSION} == "" || ${OUTPUT_VERSION} == "" || ${DIGITYPE} == "" || ${DBVERSION} == "" || ${DBPURPOSE} == "" ]]; then
  echo "Missing arguments"
  exit_abnormal
fi

PRIMARYCONF=${CAMPAIGN}${PRIMARY_VERSION}

# Test: run a test to check the SimJob for this campaign verion exists
DIR=/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${CAMPAIGN}${OUTPUT_VERSION}
if [ -d "$DIR" ];
  then
    echo "Musing $DIR exists."
  else
    echo "Musing $DIR does not exist."
    exit_abnormal
fi


if [[ "${DIGITYPE}" == "Extracted" || "${DIGITYPE}" == "NoField" ]]; then
  if [[ "${PRIMARY}" != *"${DIGITYPE}"* ]]; then
    echo "PRIMARY ${PRIMARY} doesn't match digitization type ${DIGITYPE}; aborting"
    exit_abnormal
  else
    # no need for redundant labels
    digout=$PRIMARY
  fi
  # check BFIELD here too: it must be 'null' TODO
else
  if [[ "${PRIMARY}" == *"Extracted"* || "${PRIMARY}" == *"NoField"* ]]; then
    echo "PRIMARY ${PRIMARY} incompatible with digitization type ${DIGITYPE}; aborting"
    exit_abnormal
  fi
fi
echo "Generating digitization scripts for campaign ${CAMPAIGN} primary $PRIMARY version ${PRIMARY_VERSION} musing version ${OUTPUT_VERSION} digitzation type ${DIGITYPE} database purpose, version  ${DBPURPOSE} ${DBVERSION}"

rm -f digitize.fcl
samListLocations ${SAMOPT} --defname="dts.mu2e.${PRIMARY}.${PRIMARYCONF}.art" > ${PRIMARY}.txt
echo \#include \"Production/JobConfig/digitize/Digitize.fcl\" >> digitize.fcl
echo \#include \"Production/JobConfig/digitize/${DIGITYPE}.fcl\" >> digitize.fcl
# turn off streams according to the digitization type.
if [[ "${DIGITYPE}" == "Extracted" || "${DIGITYPE}" == "NoField" ]]; then
  echo outputs.TrkOutput.fileName: \"dig.owner.${PRIMARY}${DIGITYPE}Trk.version.sequencer.art\" >> digitize.fcl
  echo outputs.CaloOutput.fileName: \"dig.owner.${PRIMARY}${DIGITYPE}Calo.version.sequencer.art\" >> digitize.fcl
  echo outputs.UntriggeredOutput.fileName: \"dig.owner.${PRIMARY}${DIGITYPE}Untriggered.version.sequencer.art\" >> digitize.fcl
else
  # keep all streams
  echo outputs.SignalOutput.fileName: \"dig.owner.${PRIMARY}${DIGITYPE}Signal.version.sequencer.art\" >> digitize.fcl
  echo outputs.DiagOutput.fileName: \"dig.owner.${PRIMARY}${DIGITYPE}Diag.version.sequencer.art\" >> digitize.fcl
  echo outputs.TrkOutput.fileName: \"dig.owner.${PRIMARY}${DIGITYPE}Trk.version.sequencer.art\" >> digitize.fcl
  echo outputs.CaloOutput.fileName: \"dig.owner.${PRIMARY}${DIGITYPE}Calo.version.sequencer.art\" >> digitize.fcl
  echo outputs.UntriggeredOutput.fileName: \"dig.owner.${PRIMARY}${DIGITYPE}Untriggered.version.sequencer.art\" >> digitize.fcl
fi
# setup database access for digi parameters
echo services.DbService.purpose: ${CAMPAIGN}_${DBPURPOSE} >> digitize.fcl
echo services.DbService.version: ${DBVERSION} >> digitize.fcl
echo services.DbService.verbose : 2 >> digitize.fcl
echo "services.GeometryService.bFieldFile : \"${FIELD}\"" >> digitize.fcl
OUTCONF=${CAMPAIGN}${OUTPUT_VERSION}_${DBPURPOSE}_${DBVERSION}
generate_fcl --dsconf="${OUTCONF}" --dsowner=${OWNER} --description="${PRIMARY}${DIGITYPE}" --embed digitize.fcl \
  --inputs="${PRIMARY}.txt" --merge-factor=${MERGE}
for dirname in 000 001 002 003 004 005 006 007 008 009; do
  if test -d $dirname; then
    echo "found dir $dirname"
    rm -rf "${PRIMARY}${DIGITYPE}_$dirname"
    echo "moving $dirname to ${PRIMARY}${DIGITYPE}_${dirname}"
    mv $dirname "${PRIMARY}${DIGITYPE}_$dirname"
  fi
done

