/*
   This file is part of the package org-clock-dbus. It is subject to
   the license terms in the LICENSE file found in the top-level
   directory of this distribution and at:

     https://github.com/pjones/org-clock-dbus

   No part of this package, including this file, may be copied,
   modified, propagated, or distributed except according to the terms
   contained in the LICENSE file.
*/

use clap::Parser;

mod cli;
mod clock;
mod monitor;

use cli::Cli;

fn main() {
    let cli = Cli::parse();

    match &cli.command {
        cli::Command::Monitor(args) => {
            monitor::monitor(args.clone()).unwrap();
        }
    }
}
