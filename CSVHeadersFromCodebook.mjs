#!/usr/bin/env node

// const inquirer = require('inquirer')
// const chalk = require('chalk')
// const shell = require('shelljs')
// import inquirer from 'inquirer'
import chalk from 'chalk'
import fs from 'fs'
// import shell from 'shelljs'
const argv = process.argv
// import fs from 'fs'
// import readline from 'readline'
import firstline from 'firstline'
import * as d3 from 'd3'
import 'd3-dsv'
import slugify from 'slugify'

const codedFile = argv[2] || ''
const codeBook = argv[3] || ''
const codeMap = argv[4].split('=') || ['','']

const showConsoleLogs = false

const decodeHeader = (headerCode, codebook, codeMap) => {
  // if (headerMap[headerCode].indexOf(',') > -1) return console.error('Has comma')
  const headerMap = {}

  codebook.map((r) => {
    headerMap[r[codeMap[0]]] = slugify(r[codeMap[1]].trim(), {
      replacement: '_',
      lower: true,
      strict: true
    })
  })

  if (headerMap[headerCode]) return headerMap[headerCode]
  else return headerCode
}

const run = async () => {

  if (showConsoleLogs) {
    console.log(
      chalk.green(`Input file: ${codedFile}`)
    )
    console.log(
      chalk.yellow(`Codebook file: ${codeBook}`)
    )
    console.log(
      chalk.yellow(`Code column: ${codeMap[0]}`)
    )
    console.log(
      chalk.yellow(`Label column: ${codeMap[1]} `)
    )
  }
  
  // Create headerMap from codebook
  fs.readFile(codeBook, 'UTF-8', function (err, csv) {
    if(err) console.error(err)

    const parsedCodebook = d3.csvParse(csv)    

    // Get header line from the coded file
    firstline(codedFile).then((l) => {
      // console.log(l)
      const codedHeaders = l.split(',')

      if (showConsoleLogs) console.log(
        chalk.bold('\nOriginal column headers:\n'),
        chalk.yellow(l)
      )

      // Go through every coded header and look up it's
      // human readable name 
      const labelHeaders = codedHeaders.map(h => {
        return decodeHeader(h, parsedCodebook, codeMap)
      })

      // And now these are our new human readable headers
      if (showConsoleLogs) {
        console.log(
          chalk.bold('\nRemapped column headers:\n'),
          chalk.green(labelHeaders.join(','))
        )
      } else console.log(labelHeaders.join(','))
    })
  })

}

run();