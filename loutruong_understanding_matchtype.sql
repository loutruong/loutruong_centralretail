SELECT
    *
FROM
    user_search_term
WHERE
    1 = 1
    AND user_search_term IN ('google_index_tag1 google_index_tag2')
    -- Exact Match: Returns results when the search query matches the keyword exactly (same words, same order)
    AND user_search_term LIKE '%google_index_tag1 google_index_tag2%'
    -- Phrase Match: Returns results containing the exact phrase as part of a larger query, preserving word order (e.g., "keyword", "keyword example", "example keyword")
    AND user_search_term LIKE '${Relative keyword with the user_search_term}'
    -- Broad Match: Returns results for any variation of the keyword — synonyms, related terms, different word orders.
    AND user_search_term LIKE '%google_index_tag1%google_index_tag2%'
    -- Broad Match Modifier: Forces certain words to be present, while allowing flexibility on others.
;