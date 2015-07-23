
Overview
========

This simple web application is meant to provide a quick way to annotate text documents.   Real annotations systems require handling multiple annotators, possibly an arbitrator, inter-annotator agreement calculations, etc but this is not meant for that use case.

Setup
=====

1. <code>sqlite3 quick\_annotations.db < db\_setup\_quick\_annotations.sql</code>
2. Load text documents into database using your own method.

Perl Modules Required
---------------------

* Mojolicious
* DBD::SQLite

Usage
=====

1. <code>perl quick\_annotations.pl daemon</code>
2. Browse to http://localhost:3000
