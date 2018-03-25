
CLASS ltcl_test DEFINITION FOR TESTING DURATION SHORT RISK LEVEL HARMLESS FINAL.

  PUBLIC SECTION.
    INTERFACES:
      if_oo_adt_intrnl_classrun PARTIALLY IMPLEMENTED.

  PRIVATE SECTION.
    METHODS: main FOR TESTING.

ENDCLASS.       "ltcl_Test


CLASS ltcl_test IMPLEMENTATION.

  METHOD main.

    NEW zcl_abapgit_import( )->if_oo_adt_classrun~main( me ).

  ENDMETHOD.

  METHOD if_oo_adt_intrnl_classrun~write_text.

    cl_abap_unit_assert=>fail(
      msg   = text
      level = if_aunit_constants=>tolerant
      quit  = if_aunit_constants=>no ).

  ENDMETHOD.

ENDCLASS.
