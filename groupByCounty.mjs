import find from 'lodash/find'
import filter from 'lodash/filter'
import sortBy from 'lodash/sortBy'
import fs from 'fs'
//import nest from 'd3-collection'
import * as collection from 'd3-collection'

let argv = process.argv


/*
const fs = require('fs').promises

const {
  nest
} = require('d3-collection')
*/

// console.log('argv', JSON.stringify(argv))

let readFile = ''
if (argv[2]) {
  readFile = argv[2]
} else {
  readFile = 'county-elections.json'
}

// There is no output file
// We just print JSON through console.log
// But if there were...
// let outputFile = ''
// if (argv[3]) {
//   outputFile = argv[3]
// } else {
//   outputFile = 'county-elections.json'
// }

async function main() {
  const file = await fs.readFileSync(readFile)
  const data = JSON.parse(file)
  
  const nestedData = collection.nest()
      .key(function(d){
        return d.FIPS
      })
      .key(function(d){
       return d.year
      })
       .entries(data) 
  const mappedData = nestedData.map(function(d,k){
    const yearEntries = d.values
    // yearEntries is full of objects which represent a candidate
    let e2016 = find(yearEntries, {
      key: '2016'
    })

    e2016.values = sortBy(e2016.values, (d) => +d.candidatevotes ).reverse()
    const e2016c1 = e2016.values[0]
    const e2016c2 = e2016.values[1]
    const e2016_votediff = +e2016c1.candidatevotes - +e2016c2.candidatevotes
    const demCand = find(e2016.values, {party: 'democrat'})
    const repCand = find(e2016.values, {party: 'republican'})

    let FIPS = +(e2016c1.FIPS)
    if (!FIPS) return false
    FIPS = FIPS.toString().padStart(5, 0)
    if (FIPS === null) return false

    return {
      'FIPS': FIPS,
      e2016_votediff,
      e2016_rep_winner: e2016c1.party === 'republican' ? true : false,
      e2016_dem_winner: e2016c1.party === 'democrat' ? true : false,
      e2016_rep_vote: +repCand.candidatevotes,
      e2016_dem_vote: +demCand.candidatevotes
    }
  })
  console.log(JSON.stringify(mappedData))
}
main()
