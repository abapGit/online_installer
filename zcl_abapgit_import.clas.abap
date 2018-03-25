CLASS zcl_abapgit_import DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .

    METHODS constructor .
  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_content,
        name TYPE string,
        path TYPE string,
        type TYPE string,
        raw  TYPE string,
      END OF ty_content .
    TYPES:
      ty_contents_tt TYPE STANDARD TABLE OF ty_content WITH EMPTY KEY .

    DATA mi_out TYPE REF TO if_oo_adt_intrnl_classrun .
    DATA mv_token TYPE string .
    DATA mv_branch TYPE string .

    METHODS http_get
      IMPORTING
        !iv_url       TYPE string
      RETURNING
        VALUE(rv_raw) TYPE string .
    METHODS parse_content
      IMPORTING
        !iv_json           TYPE string
      RETURNING
        VALUE(rt_contents) TYPE ty_contents_tt .
    METHODS read_remote
      IMPORTING
        !iv_path           TYPE string DEFAULT 'src'
      RETURNING
        VALUE(rt_contents) TYPE ty_contents_tt .
ENDCLASS.



CLASS ZCL_ABAPGIT_IMPORT IMPLEMENTATION.


  METHOD constructor.

    mv_token = ''.
    mv_branch = 'master'.

  ENDMETHOD.


  METHOD http_get.

* todo, proxy?
    cl_http_client=>create_by_url(
      EXPORTING
        url                = iv_url
        ssl_id             = 'ANONYM'
      IMPORTING
        client             = DATA(li_client)
      EXCEPTIONS
        argument_not_found = 1
        plugin_not_active  = 2
        internal_error     = 3
        OTHERS             = 4 ).
* todo, check sy-subrc

    IF NOT mv_token IS INITIAL.
      li_client->request->set_header_field(
        name  = 'user-agent'
        value = 'abapGit online installer' ).
      li_client->request->set_header_field(
        name  = 'Authorization'
        value = |token { mv_token }| ).
    ENDIF.

    li_client->send(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        http_invalid_timeout       = 4
        OTHERS                     = 5 ).
* todo, check sy-subrc

    li_client->receive(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4 ).

    rv_raw = li_client->response->get_cdata( ).

    li_client->response->get_status( IMPORTING code = DATA(lv_code) ).
    IF lv_code <> 200.
      mi_out->write_text( |HTTP error: { lv_code }, { rv_raw }| ).
    ENDIF.

  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.

    mi_out = out.

    DATA(lt_files) = read_remote( ).

* todo, loop through files and match "clas.xml" and "clas.abap"

* todo, write classes into system

* todo, call ZCL_ABAPGIT_PERSIST_MIGRATE=>TABLE_CREATE
* and ZCL_ABAPGIT_PERSIST_MIGRATE=>LOCK_CREATE and add to "transport"

    out->write_text( 'Done' ).

  ENDMETHOD.


  METHOD parse_content.

    FIND ALL OCCURRENCES OF REGEX 'name\":\"([\w.]+)' IN iv_json RESULTS DATA(lt_names).
    FIND ALL OCCURRENCES OF REGEX 'path\":\"([\w./]+)' IN iv_json RESULTS DATA(lt_paths).
    FIND ALL OCCURRENCES OF REGEX 'type\":\"(\w+)' IN iv_json RESULTS DATA(lt_types).

    ASSERT lines( lt_names ) = lines( lt_paths )
      AND lines( lt_paths ) = lines( lt_types ).

    DO lines( lt_names ) TIMES.
      DATA(lv_index) = sy-index.

      APPEND VALUE #(
        name = substring( val = iv_json off = lt_names[ lv_index ]-submatches[ 1 ]-offset len = lt_names[ lv_index ]-submatches[ 1 ]-length )
        path = substring( val = iv_json off = lt_paths[ lv_index ]-submatches[ 1 ]-offset len = lt_paths[ lv_index ]-submatches[ 1 ]-length )
        type = substring( val = iv_json off = lt_types[ lv_index ]-submatches[ 1 ]-offset len = lt_types[ lv_index ]-submatches[ 1 ]-length )
        ) TO rt_contents.
    ENDDO.

  ENDMETHOD.


  METHOD read_remote.

    DATA(lv_json) = http_get(
      'https://api.github.com/repos/larshp/abapGit/contents/' && iv_path && '?ref=' && mv_branch ).

    rt_contents = parse_content( lv_json ).

    LOOP AT rt_contents INTO DATA(ls_content) WHERE type = 'dir'.
      APPEND LINES OF read_remote( ls_content-path ) TO rt_contents.
    ENDLOOP.

    DELETE rt_contents WHERE type = 'dir'.

    DELETE rt_contents WHERE name CP '*devc.xml'.
    DELETE rt_contents WHERE name CP '*tran.xml'.
    DELETE rt_contents WHERE name CP '*prog.xml'.
    DELETE rt_contents WHERE name CP '*prog.abap'.
    DELETE rt_contents WHERE name CP '*w3mi.data.*'.
    DELETE rt_contents WHERE name CP '*w3mi.xml'.
    DELETE rt_contents WHERE name CP '*clas.testclasses.abap'. " todo, serialize testclasses?

    LOOP AT rt_contents ASSIGNING FIELD-SYMBOL(<ls_content>) WHERE raw IS INITIAL.
      <ls_content>-raw = http_get(
        'https://raw.githubusercontent.com/larshp/abapGit/' && mv_branch && '/' && <ls_content>-path ).
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
