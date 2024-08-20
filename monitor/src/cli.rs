/*
   This file is part of the package org-clock-dbus. It is subject to
   the license terms in the LICENSE file found in the top-level
   directory of this distribution and at:

     https://github.com/pjones/org-clock-dbus

   No part of this package, including this file, may be copied,
   modified, propagated, or distributed except according to the terms
   contained in the LICENSE file.
*/

use clap::{Args, Parser, Subcommand, ValueEnum};

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, ValueEnum)]
pub enum OutputMode {
    /// Plain text to standard output.
    Simple,

    /// Use the Waybar JSON format.
    Waybar,
}

impl std::fmt::Display for OutputMode {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match *self {
            OutputMode::Simple => write!(f, "simple"),
            OutputMode::Waybar => write!(f, "waybar"),
        }
    }
}

#[derive(Args, Clone, Debug)]
pub struct MonitorArgs {
    /// Select the style of output to use.
    #[arg(short, long, default_value_t = OutputMode::Simple)]
    pub mode: OutputMode,

    /// How to format org-clock strings.
    #[arg(short, long, default_value = "[{time}] {heading}")]
    pub format: String,

    /// Count down from WHEN instead of counting up (e.g.: 25m).
    #[arg(short, long, value_name = "WHEN")]
    pub down_from: Option<String>,
}

#[derive(Clone, Debug, Subcommand)]
pub enum Command {
    #[command(about = "Monitor DBus for a status bar")]
    Monitor(MonitorArgs),
}

#[derive(Clone, Debug, Parser)]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,
}
