# CADC-F14-Tomcat

i doubt this will go anywhere, or even compile if i get that far. 

idk, thought it would be fun to replicate the CADC microprocessor from the F-14 Tomcat in Verilog
the CADC isn't really a microprocessor, it's rather a collections of multiple ICs that created a "microprocessor" designed for a specific task, and calling it a microprocessor is a strech. 
basically, I'd like to make a general purpose 20-bit microprocessor, inspired by the CADC, combining all ICs into one chip. a real modern day 20-bit ASIC would be epic.
would be cool to imagine if history was different and a 20-bit computer was developed off the back of the F-14 program. 
I'd love to see what kind of stuff you could render with a 20-bit pipline, it's interesting as heck.

this is an extremely difficult project with tons of liberties taken from a lack of information/documentation.
reverse engineering the die photos instead of relying on the reports/manuals information, will be the most accurate path to creating a CADC and generalizing a system.

ideally, you would have two branches, the CADC and the CATC. the CADC branch is a pipe dream, while the CATC branch could be done with many liberties taken.
### CADC Branch
  A one-to-one, pure verilog implementation of the entire CADC system.
  You would need PMOD hardware for A/D, Sensors, and vendor specific stuff for a demo.
### CATC Branch
  General purpose 20-bit microprocessor implementation in pure verilog. The included CATC.v is the basic idea.

![alt text](https://github.com/SaxonRah/CADC-F14-Tomcat/blob/main/fig_outline.png?raw=true)

# refs
## firstmicroprocessor Info and Powerpoint on F-14
  https://firstmicroprocessor.com/wp-content/uploads/2020/02/2013powerpoint.ppt
  https://web.archive.org/web/20240118055150/https://firstmicroprocessor.com/?doing_wp_cron=1705556352.5010390281677246093750
## Ken Sherriff Reverse-engineering the mechanical Bendix Central Air Data Computer
  https://www.righto.com/2023/10/bendix-cadc-reverse-engineering.html
## NAYAIRDEVCEN Dynamic Flight Simulator F-14
  https://apps.dtic.mil/sti/tr/pdf/ADA327438.pdf
# Advanced Aircraft Electrical System (AAES) for F-14
  https://apps.dtic.mil/sti/tr/pdf/ADA047858.pdf
## NATOPS FLIGHT MANUAL NAVY MODEL F−14D AIRCRAFT
  https://info.publicintelligence.net/F14AAD-1.pdf
## NASA Advanced Flight Control System Study Final Report 
  https://core.ac.uk/download/pdf/42853936.pdf
